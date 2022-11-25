#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefInventoryTransfer, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	Header.OperationKind AS OperationKind,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.StructuralUnitPayee AS StructuralUnitPayee,
	|	Header.Cell AS Cell,
	|	Header.CellPayee AS CellPayee,
	|	Header.BasisDocument AS BasisDocument
	|INTO Header
	|FROM
	|	Document.InventoryTransfer AS Header
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryTransferInventory.LineNumber AS LineNumber,
	|	InventoryTransferInventory.ConnectionKey AS ConnectionKey,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	Header.Date AS Period,
	|	Header.OperationKind AS OperationKind,
	|	InventoryTransferInventory.Products.ProductsType AS ProductsType,
	|	CASE
	|		WHEN Header.StructuralUnit.StructuralUnitType <> VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|				AND Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailTransferEarningAccounting,
	|	CASE
	|		WHEN Header.StructuralUnit.StructuralUnitType <> VALUE(Enum.BusinessUnitsTypes.Retail)
	|				AND Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailTransfer,
	|	CASE
	|		WHEN Header.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|				AND Header.StructuralUnitPayee.StructuralUnitType <> VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ReturnFromRetailEarningAccounting,
	|	CASE
	|		WHEN Header.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|				AND Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS TransferInRetailEarningAccounting,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.StructuralUnit.MarkupGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS MarkupGLAccount,
	|	Header.StructuralUnit.RetailPriceKind AS RetailPriceKind,
	|	Header.StructuralUnit.RetailPriceKind.PriceCurrency AS PriceCurrency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryTransferInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS FinancialAccountInRetailRecipient,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.StructuralUnitPayee.MarkupGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS MarkupGLAccountRecipient,
	|	Header.StructuralUnitPayee.RetailPriceKind AS RetailPriceKindRecipient,
	|	Header.StructuralUnitPayee.RetailPriceKind.PriceCurrency AS CurrencyPricesRecipient,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(Enum.GLAccountsTypes.EmptyRef)
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|				AND Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN InventoryTransferInventory.ConsumptionGLAccount.TypeOfAccount
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|			THEN InventoryTransferInventory.InventoryToGLAccount.TypeOfAccount
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.TransferToOperation)
	|			THEN InventoryTransferInventory.SignedOutEquipmentGLAccount.TypeOfAccount
	|	END AS ExpenseAccountType,
	|	InventoryTransferInventory.BusinessLine AS CorrActivityDirection,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	Header.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|			OR Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|			THEN Header.StructuralUnitPayee
	|		ELSE InventoryTransferInventory.BusinessUnit
	|	END AS StructuralUnitCorr,
	|	Header.Cell AS Cell,
	|	Header.CellPayee AS CorrCell,
	|	InventoryTransferInventory.ExpenseItem AS ExpenseItem,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|				OR CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
	|			THEN InventoryTransferInventory.InventoryReceivedGLAccount
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN InventoryTransferInventory.ConsumptionGLAccount
	|		ELSE CASE
	|				WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|					THEN InventoryTransferInventory.SignedOutEquipmentGLAccount
	|				ELSE InventoryTransferInventory.InventoryGLAccount
	|			END
	|	END AS GLAccount,
	|	CASE
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|			THEN VALUE(Enum.InventoryAccountTypes.SignedOutEquipment)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|			THEN CASE
	|					WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|						THEN InventoryTransferInventory.InventoryReceivedGLAccount
	|					ELSE InventoryTransferInventory.InventoryGLAccount
	|				END
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|			THEN InventoryTransferInventory.ConsumptionGLAccount
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.TransferToOperation)
	|			THEN InventoryTransferInventory.SignedOutEquipmentGLAccount
	|	END AS CorrGLAccount,
	|	CASE
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.TransferToOperation)
	|			THEN VALUE(Enum.InventoryAccountTypes.SignedOutEquipment)
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|			THEN VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS CorrInventoryAccountType,
	|	InventoryTransferInventory.Products AS Products,
	|	CASE
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|				OR Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.TransferToOperation)
	|			THEN InventoryTransferInventory.Products
	|		ELSE UNDEFINED
	|	END AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryTransferInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|				OR Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.TransferToOperation)
	|			THEN CASE
	|					WHEN &UseCharacteristics
	|						THEN InventoryTransferInventory.Characteristic
	|					ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|				END
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|				AND Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|				AND (ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN InventoryTransferInventory.Batch
	|		WHEN &UseBatches
	|				AND Header.OperationKind <> VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN InventoryTransferInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN &UseBatches
	|				AND Header.OperationKind <> VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|				AND (ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN InventoryTransferInventory.Batch
	|		WHEN &UseBatches
	|				AND Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN InventoryTransferInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchCorr,
	|	CASE
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|			THEN InventoryTransferInventory.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS SalesOrder,
	|	CASE
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|				AND (VALUETYPE(InventoryTransferInventory.SalesOrder) = TYPE(Document.SalesOrder)
	|					OR VALUETYPE(InventoryTransferInventory.SalesOrder) = TYPE(Document.TransferOrder)
	|					OR VALUETYPE(InventoryTransferInventory.SalesOrder) = TYPE(Document.WorkOrder))
	|			THEN InventoryTransferInventory.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS CustomerCorrOrder,
	|	CASE
	|		WHEN VALUETYPE(InventoryTransferInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN InventoryTransferInventory.Quantity
	|		ELSE InventoryTransferInventory.Quantity * InventoryTransferInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(InventoryTransferInventory.SalesOrder) = TYPE(Document.TransferOrder)
	|				OR Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|					AND VALUETYPE(InventoryTransferInventory.SalesOrder) = TYPE(Document.WorkOrder)
	|			THEN CASE
	|					WHEN VALUETYPE(InventoryTransferInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|						THEN InventoryTransferInventory.Reserve
	|					ELSE InventoryTransferInventory.Reserve * InventoryTransferInventory.MeasurementUnit.Factor
	|				END
	|		ELSE 0
	|	END AS Reserve,
	|	0 AS Amount,
	|	InventoryTransferInventory.Amount AS Cost,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|			THEN CASE
	|					WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|						THEN InventoryTransferInventory.InventoryReceivedGLAccount
	|					ELSE CASE
	|							WHEN Header.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|										AND Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|									OR Header.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|										AND Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|									OR Header.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|										AND Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|								THEN InventoryTransferInventory.InventoryToGLAccount
	|							WHEN Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|									OR Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|									OR Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|								THEN InventoryTransferInventory.InventoryToGLAccount
	|							ELSE InventoryTransferInventory.ConsumptionGLAccount
	|						END
	|				END
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|			THEN InventoryTransferInventory.ConsumptionGLAccount
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.TransferToOperation)
	|			THEN InventoryTransferInventory.SignedOutEquipmentGLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation)
	|			THEN InventoryTransferInventory.SignedOutEquipmentGLAccount
	|		ELSE CASE
	|				WHEN Header.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|						OR Header.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|						OR Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|					THEN InventoryTransferInventory.InventoryGLAccount
	|				ELSE InventoryTransferInventory.ConsumptionGLAccount
	|			END
	|	END AS AccountCr,
	|	&InventoryTransfer AS Content,
	|	&InventoryTransfer AS ContentOfAccountingRecord,
	|	InventoryTransferInventory.Amount AS AmountReturnCur,
	|	CASE
	|		WHEN VALUETYPE(Header.BasisDocument) = TYPE(Document.WorkOrder)
	|			THEN Header.BasisDocument
	|		ELSE VALUE(Document.WorkOrder.EmptyRef)
	|	END AS WorkOrder,
	|	InventoryTransferInventory.Ownership AS Ownership,
	|	InventoryTransferInventory.Ownership AS OwnershipCorr,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	FALSE AS SerialNumber,
	|	InventoryTransferInventory.Work AS Work,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryTransferInventory.WorkCharacteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS WorkCharacteristic,
	|	Header.Ref AS Document
	|INTO TemporaryTableInventory
	|FROM
	|	Document.InventoryTransfer.Inventory AS InventoryTransferInventory
	|		INNER JOIN Header AS Header
	|		ON (Header.Ref = InventoryTransferInventory.Ref)
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON InventoryTransferInventory.Ownership = CatalogInventoryOwnership.Ref
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON InventoryTransferInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON (Header.StructuralUnit = BatchTrackingPolicy.StructuralUnit)
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicyCorr
	|		ON (Header.StructuralUnitPayee = BatchTrackingPolicyCorr.StructuralUnit)
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicyCorr.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPoliciesCorr
	|		ON (BatchTrackingPolicyCorr.Policy = BatchTrackingPoliciesCorr.Ref)
	|WHERE
	|	Header.OperationKind <> VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|
	|UNION ALL
	|
	|SELECT
	|	InventoryTransferInventoryOwnership.LineNumber,
	|	NULL,
	|	VALUE(AccumulationRecordType.Expense),
	|	Header.Date,
	|	Header.OperationKind,
	|	InventoryTransferInventoryOwnership.Products.ProductsType,
	|	CASE
	|		WHEN Header.StructuralUnit.StructuralUnitType <> VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|				AND Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	CASE
	|		WHEN Header.StructuralUnit.StructuralUnitType <> VALUE(Enum.BusinessUnitsTypes.Retail)
	|				AND Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	CASE
	|		WHEN Header.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|				AND Header.StructuralUnitPayee.StructuralUnitType <> VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	CASE
	|		WHEN Header.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|				AND Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.StructuralUnit.MarkupGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	Header.StructuralUnit.RetailPriceKind,
	|	Header.StructuralUnit.RetailPriceKind.PriceCurrency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryTransferInventoryOwnership.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.StructuralUnitPayee.MarkupGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	Header.StructuralUnitPayee.RetailPriceKind,
	|	Header.StructuralUnitPayee.RetailPriceKind.PriceCurrency,
	|	CASE
	|		WHEN Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN InventoryTransferInventoryOwnership.ConsumptionGLAccount.TypeOfAccount
	|		ELSE InventoryTransferInventoryOwnership.InventoryToGLAccount.TypeOfAccount
	|	END,
	|	InventoryTransferInventoryOwnership.BusinessLine,
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	Header.StructuralUnit,
	|	CASE
	|		WHEN TRUE
	|			THEN Header.StructuralUnitPayee
	|		ELSE InventoryTransferInventoryOwnership.BusinessUnit
	|	END,
	|	Header.Cell,
	|	Header.CellPayee,
	|	InventoryTransferInventoryOwnership.ExpenseItem,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|				OR CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
	|			THEN InventoryTransferInventoryOwnership.InventoryReceivedGLAccount
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN InventoryTransferInventoryOwnership.ConsumptionGLAccount
	|		ELSE InventoryTransferInventoryOwnership.InventoryGLAccount
	|	END,
	|	CASE
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.ThirdPartyInventory)
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
	|			THEN InventoryTransferInventoryOwnership.InventoryReceivedGLAccount
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN InventoryTransferInventoryOwnership.ConsumptionGLAccount
	|		ELSE InventoryTransferInventoryOwnership.InventoryToGLAccount
	|	END,
	|	CASE
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.ThirdPartyInventory)
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END,
	|	InventoryTransferInventoryOwnership.Products,
	|	InventoryTransferInventoryOwnership.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryTransferInventoryOwnership.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryTransferInventoryOwnership.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryTransferInventoryOwnership.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN InventoryTransferInventoryOwnership.BatchCorr
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END,
	|	InventoryTransferInventoryOwnership.SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(InventoryTransferInventoryOwnership.SalesOrder) = TYPE(Document.SalesOrder)
	|				OR VALUETYPE(InventoryTransferInventoryOwnership.SalesOrder) = TYPE(Document.TransferOrder)
	|				OR VALUETYPE(InventoryTransferInventoryOwnership.SalesOrder) = TYPE(Document.WorkOrder)
	// begin Drive.FullVersion
	|				OR VALUETYPE(InventoryTransferInventoryOwnership.SalesOrder) = TYPE(Document.SubcontractorOrderReceived)
	|				OR VALUETYPE(InventoryTransferInventoryOwnership.SalesOrder) = TYPE(Document.ProductionOrder)
	|				OR VALUETYPE(InventoryTransferInventoryOwnership.SalesOrder) = TYPE(Document.ManufacturingOperation)
	// end Drive.FullVersion
	|			THEN InventoryTransferInventoryOwnership.SalesOrder
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END,
	|	InventoryTransferInventoryOwnership.Quantity,
	|	CASE
	|		WHEN VALUETYPE(InventoryTransferInventoryOwnership.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN InventoryTransferInventoryOwnership.Reserve
	|		ELSE InventoryTransferInventoryOwnership.Reserve * InventoryTransferInventoryOwnership.MeasurementUnit.Factor
	|	END,
	|	0,
	|	InventoryTransferInventoryOwnership.Amount,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|				OR CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
	|			THEN InventoryTransferInventoryOwnership.InventoryReceivedGLAccount
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN InventoryTransferInventoryOwnership.ConsumptionGLAccount
	|		ELSE CASE
	|				WHEN Header.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|							AND Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|						OR Header.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|							AND Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|						OR Header.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|							AND Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|					THEN InventoryTransferInventoryOwnership.InventoryToGLAccount
	|				WHEN Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|						OR Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|						OR Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|					THEN InventoryTransferInventoryOwnership.InventoryToGLAccount
	|				ELSE InventoryTransferInventoryOwnership.ConsumptionGLAccount
	|			END
	|	END,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|				OR CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
	|			THEN InventoryTransferInventoryOwnership.InventoryReceivedGLAccount
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
	|			THEN InventoryTransferInventoryOwnership.ConsumptionGLAccount
	|		ELSE CASE
	|				WHEN Header.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|						OR Header.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|						OR Header.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|					THEN InventoryTransferInventoryOwnership.InventoryGLAccount
	|				ELSE InventoryTransferInventoryOwnership.ConsumptionGLAccount
	|			END
	|	END,
	|	&InventoryTransfer,
	|	&InventoryTransfer,
	|	InventoryTransferInventoryOwnership.Amount,
	|	CASE
	|		WHEN VALUETYPE(Header.BasisDocument) = TYPE(Document.WorkOrder)
	|			THEN Header.BasisDocument
	|		ELSE VALUE(Document.WorkOrder.EmptyRef)
	|	END,
	|	InventoryTransferInventoryOwnership.Ownership,
	|	InventoryTransferInventoryOwnership.Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef),
	|	InventoryTransferInventoryOwnership.SerialNumber,
	|	InventoryTransferInventoryOwnership.Work,
	|	InventoryTransferInventoryOwnership.WorkCharacteristic,
	|	Header.Ref
	|FROM
	|	Document.InventoryTransfer.InventoryOwnership AS InventoryTransferInventoryOwnership
	|		INNER JOIN Header AS Header
	|		ON (Header.Ref = InventoryTransferInventoryOwnership.Ref)
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON InventoryTransferInventoryOwnership.Ownership = CatalogInventoryOwnership.Ref
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON InventoryTransferInventoryOwnership.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicyCorr
	|		ON (Header.StructuralUnitPayee = BatchTrackingPolicyCorr.StructuralUnit)
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicyCorr.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPoliciesCorr
	|		ON (BatchTrackingPolicyCorr.Policy = BatchTrackingPoliciesCorr.Ref)
	|WHERE
	|	Header.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryTransferSerialNumbers.ConnectionKey AS ConnectionKey,
	|	InventoryTransferSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.InventoryTransfer.SerialNumbers AS InventoryTransferSerialNumbers
	|WHERE
	|	InventoryTransferSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	Query.SetParameter("Ref",							DocumentRefInventoryTransfer);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseCharacteristics",			StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseStorageBins",				StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseBatches", 					StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseSerialNumbers",				StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("InventoryTransfer", NStr("en = 'Inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'Traslado del inventario';es_CO = 'Transferencia de inventario';tr = 'Stok transferi';it = 'Movimenti di scorte';de = 'Bestandsumlagerung'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();

	// Creation of document postings.
	GenerateTableInventoryInWarehouses(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	GenerateTablePOSSummary(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	GenerateTableWorkOrders(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	
	DriveServer.GenerateTransactionsTable(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	
	GenerateTableAccountingJournalEntries(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	
	GenerateTableTransferOrders(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	GenerateTableSales(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	GenerateTableReservedProducts(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	
	// Template accounting
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefInventoryTransfer, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefInventoryTransfer, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefInventoryTransfer, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the "InventoryTransferAtWarehouseChange",
	// "RegisterRecordsInventoryChange" temporary tables contain records, it is necessary to control the sales of goods.
	
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		Or StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.RegisterRecordsTransferOrdersChange
		Or StructureTemporaryTables.RegisterRecordsPOSSummaryChange
		Or StructureTemporaryTables.RegisterRecordsSerialNumbersChange
		Or StructureTemporaryTables.RegisterRecordsWorkOrdersChange
		Or StructureTemporaryTables.RegisterRecordsReservedProductsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryInWarehousesChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Ownership AS OwnershipPresentation,
		|	RegisterRecordsInventoryInWarehousesChange.Cell AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryInWarehousesOfBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		INNER JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, Products, Characteristic, Batch, Ownership, Cell) IN
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
		|			AND (ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsInventoryChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryChange.InventoryAccountType AS InventoryAccountType,
		|	RegisterRecordsInventoryChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryChange.Batch AS BatchPresentation,
		|	RegisterRecordsInventoryChange.Ownership AS OwnershipPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		INNER JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
		|					(SELECT
		|						RegisterRecordsInventoryChange.Company AS Company,
		|						RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryChange.InventoryAccountType AS InventoryAccountType,
		|						RegisterRecordsInventoryChange.Products AS Products,
		|						RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryChange.Batch AS Batch,
		|						RegisterRecordsInventoryChange.Ownership AS Ownership,
		|						RegisterRecordsInventoryChange.CostObject AS CostObject
		|					FROM
		|						RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange)) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.PresentationCurrency = InventoryBalances.PresentationCurrency
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.InventoryAccountType = InventoryBalances.InventoryAccountType
		|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.Ownership = InventoryBalances.Ownership
		|			AND RegisterRecordsInventoryChange.CostObject = InventoryBalances.CostObject
		|			AND (ISNULL(InventoryBalances.QuantityBalance, 0) < 0)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPOSSummaryChange.LineNumber AS LineNumber,
		|	RegisterRecordsPOSSummaryChange.Company AS CompanyPresentation,
		|	RegisterRecordsPOSSummaryChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsPOSSummaryChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsPOSSummaryChange.StructuralUnit.RetailPriceKind.PriceCurrency AS CurrencyPresentation,
		|	ISNULL(POSSummaryBalances.AmountBalance, 0) AS AmountBalance,
		|	RegisterRecordsPOSSummaryChange.SumCurChange + ISNULL(POSSummaryBalances.AmountCurBalance, 0) AS BalanceInRetail,
		|	RegisterRecordsPOSSummaryChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsPOSSummaryChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsPOSSummaryChange.AmountChange AS AmountChange,
		|	RegisterRecordsPOSSummaryChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsPOSSummaryChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsPOSSummaryChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsPOSSummaryChange.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsPOSSummaryChange.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsPOSSummaryChange.CostUpdate AS CostUpdate
		|FROM
		|	RegisterRecordsPOSSummaryChange AS RegisterRecordsPOSSummaryChange
		|		INNER JOIN AccumulationRegister.POSSummary.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, StructuralUnit) IN
		|					(SELECT
		|						RegisterRecordsPOSSummaryChange.Company AS Company,
		|						RegisterRecordsPOSSummaryChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsPOSSummaryChange.StructuralUnit AS StructuralUnit
		|					FROM
		|						RegisterRecordsPOSSummaryChange AS RegisterRecordsPOSSummaryChange)) AS POSSummaryBalances
		|		ON RegisterRecordsPOSSummaryChange.Company = POSSummaryBalances.Company
		|			AND RegisterRecordsPOSSummaryChange.PresentationCurrency = POSSummaryBalances.PresentationCurrency
		|			AND RegisterRecordsPOSSummaryChange.StructuralUnit = POSSummaryBalances.StructuralUnit
		|			AND (ISNULL(POSSummaryBalances.AmountCurBalance, 0) < 0)
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsWorkOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsWorkOrdersChange.Company AS CompanyPresentation,
		|	RegisterRecordsWorkOrdersChange.WorkOrder AS OrderPresentation,
		|	RegisterRecordsWorkOrdersChange.Products AS ProductsPresentation,
		|	RegisterRecordsWorkOrdersChange.Characteristic AS CharacteristicPresentation,
		|	WorkOrdersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsWorkOrdersChange.QuantityChange, 0) + ISNULL(WorkOrdersBalances.QuantityBalance, 0) AS BalanceWorkOrders,
		|	ISNULL(WorkOrdersBalances.QuantityBalance, 0) AS QuantityBalanceWorkOrders
		|FROM
		|	RegisterRecordsWorkOrdersChange AS RegisterRecordsWorkOrdersChange
		|		INNER JOIN AccumulationRegister.WorkOrders.Balance(&ControlTime, ) AS WorkOrdersBalances
		|		ON RegisterRecordsWorkOrdersChange.Company = WorkOrdersBalances.Company
		|			AND RegisterRecordsWorkOrdersChange.WorkOrder = WorkOrdersBalances.WorkOrder
		|			AND RegisterRecordsWorkOrdersChange.Products = WorkOrdersBalances.Products
		|			AND RegisterRecordsWorkOrdersChange.Characteristic = WorkOrdersBalances.Characteristic
		|			AND (ISNULL(WorkOrdersBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");

		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter() + GenerateQueryTextBalancesTransferOrders();
		
		Query.Text = Query.Text + AccumulationRegisters.ReservedProducts.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();

		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty()
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[3].IsEmpty()
			Or Not ResultsArray[4].IsEmpty()
			Or Not ResultsArray[5].IsEmpty()
			Or Not ResultsArray[6].IsEmpty() Then
			DocumentObjectInventoryTransfer = DocumentRefInventoryTransfer.GetObject()
		EndIf;

		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		// Negative balance of inventory and cost accounting.
		ElsIf Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		// Negative balance of need for reserved products.
		ElsIf Not ResultsArray[6].IsEmpty() Then
			QueryResultSelection = ResultsArray[6].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		Else
			// Negative balance of inventory with reserves.
			DriveServer.CheckAvailableStockBalance(DocumentObjectInventoryTransfer, AdditionalProperties, Cancel);
		EndIf;
		
		// Negative balance according to the amount-based account in retail.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToPOSSummaryRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If NOT ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on work order.
		If NOT ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToWorkOrdersRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on transfer order.
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToTransferOrdersRegisterErrors(DocumentObjectInventoryTransfer, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillByTransfersOrders(DocumentData, FilterData, Inventory) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	TransferOrder.Ref AS Ref
	|INTO TT_TransferOrders
	|FROM
	|	Document.TransferOrder AS TransferOrder
	|WHERE
	|	&OrdersConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Inventory.SalesOrder AS Order,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	SUM(Inventory.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyTransfered
	|FROM
	|	Document.InventoryTransfer.Inventory AS Inventory
	|		INNER JOIN TT_TransferOrders AS TT_TransferOrders
	|		ON Inventory.SalesOrder = TT_TransferOrders.Ref
	|		INNER JOIN Document.GoodsIssue AS InventoryTransferDocument
	|		ON Inventory.Ref = InventoryTransferDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON Inventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON Inventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	InventoryTransferDocument.Posted
	|	AND Inventory.Ref <> &Ref
	|	AND ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	Inventory.Batch,
	|	Inventory.SalesOrder,
	|	Inventory.Products,
	|	Inventory.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.TransferOrder AS TransferOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_OrdersBalances
	|FROM
	|	(SELECT
	|		OrdersBalance.TransferOrder AS TransferOrder,
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.TransferOrders.Balance(
	|				,
	|				TransferOrder IN
	|					(SELECT
	|						TT_TransferOrders.Ref
	|					FROM
	|						TT_TransferOrders)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsOrders.TransferOrder,
	|		DocumentRegisterRecordsOrders.Products,
	|		DocumentRegisterRecordsOrders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsOrders.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.TransferOrders AS DocumentRegisterRecordsOrders
	|	WHERE
	|		DocumentRegisterRecordsOrders.Recorder = &Ref) AS OrdersBalance
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON OrdersBalance.Products = ProductsCatalog.Ref
	|WHERE
	|	ProductsCatalog.ProductsType IN (VALUE(Enum.ProductsTypes.InventoryItem), VALUE(Enum.ProductsTypes.Service))
	|
	|GROUP BY
	|	OrdersBalance.TransferOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrderInventory.LineNumber AS LineNumber,
	|	OrderInventory.Products AS Products,
	|	OrderInventory.Characteristic AS Characteristic,
	|	OrderInventory.Batch AS Batch,
	|	OrderInventory.Quantity AS Quantity,
	|	OrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	OrderInventory.Ref AS Order
	|INTO TT_Products
	|FROM
	|	Document.TransferOrder.Inventory AS OrderInventory
	|		INNER JOIN TT_TransferOrders AS TT_TransferOrders
	|		ON OrderInventory.Ref = TT_TransferOrders.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON OrderInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON OrderInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	TT_Products.Order AS Order,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.Quantity * TT_Products.Factor AS BaseQuantity,
	|	SUM(TT_ProductsCumulative.Quantity * TT_ProductsCumulative.Factor) AS BaseQuantityCumulative
	|INTO TT_ProductsCumulative
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_Products AS TT_ProductsCumulative
	|		ON TT_Products.Products = TT_ProductsCumulative.Products
	|			AND TT_Products.Characteristic = TT_ProductsCumulative.Characteristic
	|			AND TT_Products.Batch = TT_ProductsCumulative.Batch
	|			AND TT_Products.Order = TT_ProductsCumulative.Order
	|			AND TT_Products.LineNumber >= TT_ProductsCumulative.LineNumber
	|
	|GROUP BY
	|	TT_Products.LineNumber,
	|	TT_Products.Products,
	|	TT_Products.Characteristic,
	|	TT_Products.Batch,
	|	TT_Products.Order,
	|	TT_Products.Factor,
	|	TT_Products.Quantity * TT_Products.Factor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsCumulative.LineNumber AS LineNumber,
	|	TT_ProductsCumulative.Products AS Products,
	|	TT_ProductsCumulative.Characteristic AS Characteristic,
	|	TT_ProductsCumulative.Batch AS Batch,
	|	TT_ProductsCumulative.Order AS Order,
	|	TT_ProductsCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyTransfered.BaseQuantity > TT_ProductsCumulative.BaseQuantityCumulative - TT_ProductsCumulative.BaseQuantity
	|			THEN TT_ProductsCumulative.BaseQuantityCumulative - TT_AlreadyTransfered.BaseQuantity
	|		ELSE TT_ProductsCumulative.BaseQuantity
	|	END AS BaseQuantity
	|INTO TT_ProductsNotYetTransfered
	|FROM
	|	TT_ProductsCumulative AS TT_ProductsCumulative
	|		LEFT JOIN TT_AlreadyTransfered AS TT_AlreadyTransfered
	|		ON TT_ProductsCumulative.Products = TT_AlreadyTransfered.Products
	|			AND TT_ProductsCumulative.Characteristic = TT_AlreadyTransfered.Characteristic
	|			AND TT_ProductsCumulative.Batch = TT_AlreadyTransfered.Batch
	|			AND TT_ProductsCumulative.Order = TT_AlreadyTransfered.Order
	|WHERE
	|	ISNULL(TT_AlreadyTransfered.BaseQuantity, 0) < TT_ProductsCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetTransfered.LineNumber AS LineNumber,
	|	TT_ProductsNotYetTransfered.Products AS Products,
	|	TT_ProductsNotYetTransfered.Characteristic AS Characteristic,
	|	TT_ProductsNotYetTransfered.Batch AS Batch,
	|	TT_ProductsNotYetTransfered.Order AS Order,
	|	TT_ProductsNotYetTransfered.Factor AS Factor,
	|	TT_ProductsNotYetTransfered.BaseQuantity AS BaseQuantity,
	|	SUM(TT_ProductsNotYetTransferedCumulative.BaseQuantity) AS BaseQuantityCumulative
	|INTO TT_ProductsNotYetTransferedCumulative
	|FROM
	|	TT_ProductsNotYetTransfered AS TT_ProductsNotYetTransfered
	|		INNER JOIN TT_ProductsNotYetTransfered AS TT_ProductsNotYetTransferedCumulative
	|		ON TT_ProductsNotYetTransfered.Products = TT_ProductsNotYetTransferedCumulative.Products
	|			AND TT_ProductsNotYetTransfered.Characteristic = TT_ProductsNotYetTransferedCumulative.Characteristic
	|			AND TT_ProductsNotYetTransfered.Batch = TT_ProductsNotYetTransferedCumulative.Batch
	|			AND TT_ProductsNotYetTransfered.Order = TT_ProductsNotYetTransferedCumulative.Order
	|			AND TT_ProductsNotYetTransfered.LineNumber >= TT_ProductsNotYetTransferedCumulative.LineNumber
	|
	|GROUP BY
	|	TT_ProductsNotYetTransfered.LineNumber,
	|	TT_ProductsNotYetTransfered.Products,
	|	TT_ProductsNotYetTransfered.Characteristic,
	|	TT_ProductsNotYetTransfered.Batch,
	|	TT_ProductsNotYetTransfered.Order,
	|	TT_ProductsNotYetTransfered.Factor,
	|	TT_ProductsNotYetTransfered.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ProductsNotYetTransferedCumulative.LineNumber AS LineNumber,
	|	TT_ProductsNotYetTransferedCumulative.Products AS Products,
	|	TT_ProductsNotYetTransferedCumulative.Characteristic AS Characteristic,
	|	TT_ProductsNotYetTransferedCumulative.Batch AS Batch,
	|	TT_ProductsNotYetTransferedCumulative.Order AS Order,
	|	TT_ProductsNotYetTransferedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetTransferedCumulative.BaseQuantityCumulative
	|			THEN TT_ProductsNotYetTransferedCumulative.BaseQuantity
	|		WHEN TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetTransferedCumulative.BaseQuantityCumulative - TT_ProductsNotYetTransferedCumulative.BaseQuantity
	|			THEN TT_OrdersBalances.QuantityBalance - (TT_ProductsNotYetTransferedCumulative.BaseQuantityCumulative - TT_ProductsNotYetTransferedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_ProductsToBeTransfered
	|FROM
	|	TT_ProductsNotYetTransferedCumulative AS TT_ProductsNotYetTransferedCumulative
	|		INNER JOIN TT_OrdersBalances AS TT_OrdersBalances
	|		ON TT_ProductsNotYetTransferedCumulative.Products = TT_OrdersBalances.Products
	|			AND TT_ProductsNotYetTransferedCumulative.Characteristic = TT_OrdersBalances.Characteristic
	|			AND TT_ProductsNotYetTransferedCumulative.Order = TT_OrdersBalances.TransferOrder
	|WHERE
	|	TT_OrdersBalances.QuantityBalance > TT_ProductsNotYetTransferedCumulative.BaseQuantityCumulative - TT_ProductsNotYetTransferedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Products.Quantity * TT_Products.Factor AS NUMBER(15, 3))) = TT_ProductsToBeTransfered.BaseQuantity
	|			THEN TT_Products.Quantity
	|		ELSE CAST(TT_ProductsToBeTransfered.BaseQuantity / TT_Products.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Products.MeasurementUnit AS MeasurementUnit,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.Order AS SalesOrder,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue
	|INTO TT_InventoryToFillReserve
	|FROM
	|	TT_Products AS TT_Products
	|		INNER JOIN TT_ProductsToBeTransfered AS TT_ProductsToBeTransfered
	|		ON TT_Products.LineNumber = TT_ProductsToBeTransfered.LineNumber
	|			AND TT_Products.Order = TT_ProductsToBeTransfered.Order
	|";
	
	
	If Constants.UseInventoryReservation.Get() AND ValueIsFilled(DocumentData.StructuralUnit) Then
		Query.Text = Query.Text + GetFillReserveColumnQueryText();
	Else
		Query.Text = StrReplace(Query.Text, "INTO TT_InventoryToFillReserve", "");
	EndIf;
	
	Query.Text = Query.Text + "
	|ORDER BY
	|	TT_Products.LineNumber";
	
	
	If FilterData.Property("OrdersArray") Then
		FilterString = "TransferOrder.Ref IN(&OrdersArray)";
		Query.SetParameter("OrdersArray", FilterData.OrdersArray);
	Else
		FilterString = "";
		NotFirstItem = False;
		
		For Each FilterItem In FilterData Do
			
			If NotFirstItem Then
				FilterString = FilterString + "
				|	AND ";
			Else
				NotFirstItem = True;
			EndIf;
			
			FilterString = FilterString + "TransferOrder." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
			
		EndDo;
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&OrdersConditions", FilterString);
	
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(DocumentData.Company));
	Query.SetParameter("StructuralUnit", DocumentData.StructuralUnit);
	
	Inventory.Load(Query.Execute().Unload());

EndProcedure

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Parameters.Insert("TableName", "Inventory");
	
	If DocObject.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer Then
		
		AmountFields = New Array;
		AmountFields.Add("Amount");
		AmountFields.Add("Reserve");
		Parameters.Insert("AmountFields", AmountFields);
		
		HeaderFields = New Structure;
		HeaderFields.Insert("Company", "Company");
		HeaderFields.Insert("StructuralUnit", "StructuralUnit");
		HeaderFields.Insert("Cell", "Cell");
		
		Parameters.Insert("HeaderFields", HeaderFields);
		
		// for consistency check between Inventory and Inventory ownership fields
		NotUsedFields = New Array;
		NotUsedFields.Add("ConnectionKey");
		NotUsedFields.Add("SerialNumbers");
		Parameters.Insert("NotUsedFields", NotUsedFields);
		
		// begin Drive.FullVersion
		If TypeOf(DocObject.SalesOrder) = Type("DocumentRef.SubcontractorOrderReceived") Then
			
			OwnershipParameters = New Structure(
			"OwnershipType, Counterparty, Contract", 
			Enums.InventoryOwnershipTypes.CustomerProvidedInventory);
			
			FillPropertyValues(OwnershipParameters, DocObject.SalesOrder);
			
			Parameters.Insert("DefaultOwnership", Catalogs.InventoryOwnership.GetByParameters(OwnershipParameters));
			
		ElsIf DocObject.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer
			And DocObject.BasisDocument <> Undefined
			And TypeOf(DocObject.BasisDocument) = Type("DocumentRef.ManufacturingOperation") Then
			
			Try
				SORRef = DocObject.BasisDocument.BasisDocument.BasisDocument;
			Except
				SORRef = Undefined;
			EndTry;
			
			If TypeOf(SORRef) = Type("DocumentRef.SubcontractorOrderReceived") Then
			
				Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CustomerProvidedInventory);
			
			EndIf;
			
		EndIf;
		// end Drive.FullVersion 
		
	Else
		
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
		
	EndIf;
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region Batches

Function BatchCheckFillingParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Warehouses = New Array;
	
	If DocObject.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer
		Or DocObject.OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
		WarehouseData.Insert("TrackingArea", "Outbound_Transfer");
		Warehouses.Add(WarehouseData);
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.StructuralUnitPayee);
		WarehouseData.Insert("TrackingArea", "Inbound_Transfer");
		Warehouses.Add(WarehouseData);
		
	ElsIf DocObject.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
		WarehouseData.Insert("TrackingArea", "InventoryWriteOff");
		Warehouses.Add(WarehouseData);
		
	ElsIf DocObject.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
		WarehouseData.Insert("TrackingArea", "Inbound_Transfer");
		Warehouses.Add(WarehouseData);
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.StructuralUnitPayee);
		WarehouseData.Insert("TrackingArea", "Outbound_Transfer");
		Warehouses.Add(WarehouseData);
		
	EndIf;
	
	Parameters.Insert("Warehouses", Warehouses);
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	
	If StructureData.TabName = "Inventory"
		And StructureData.ObjectParameters.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses Then
		Result.Insert("ConsumptionGLAccount", "ExpenseItem");
	EndIf;

	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	// begin Drive.FullVersion
	If TypeOf(ObjectParameters.SalesOrder) = Type("DocumentRef.SubcontractorOrderReceived") Then
		GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
		Return GLAccountsForFilling;
	EndIf;
	// end Drive.FullVersion
	
	GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
	GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
	
	If ObjectParameters.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer Then
		GLAccountsForFilling.Insert("InventoryToGLAccount", StructureData.InventoryToGLAccount);
	ElsIf ObjectParameters.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses Then
		GLAccountsForFilling.Insert("ConsumptionGLAccount", StructureData.ConsumptionGLAccount); 
	Else
		GLAccountsForFilling.Insert("SignedOutEquipmentGLAccount", StructureData.SignedOutEquipmentGLAccount);
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Function checks if the document is
// posted and calls the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_InventoryTransfer";

	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		Query.SetParameter("CurrentDocument", CurrentDocument);
		
		If TemplateName = "MerchandiseFillingFormSender" Then
			
			Query.Text = 
			"SELECT ALLOWED
			|	InventoryTransfer.Date AS DocumentDate,
			|	InventoryTransfer.StructuralUnit AS WarehousePresentation,
			|	InventoryTransfer.Cell AS CellPresentation,
			|	InventoryTransfer.Number,
			|	InventoryTransfer.Company.Prefix AS Prefix,
			|	InventoryTransfer.Inventory.(
			|		LineNumber AS LineNumber,
			|		Products.Warehouse AS Warehouse,
			|		Products.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(InventoryTransfer.Inventory.Products.DescriptionFull AS String(100))) = """"
			|				THEN InventoryTransfer.Inventory.Products.Description
			|			ELSE InventoryTransfer.Inventory.Products.DescriptionFull
			|		END AS InventoryItem,
			|		Products.SKU AS SKU,
			|		Products.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		Products.ProductsType AS ProductsType,
			|		ConnectionKey
			|	),
			|	InventoryTransfer.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.InventoryTransfer AS InventoryTransfer
			|WHERE
			|	InventoryTransfer.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
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
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryTransfer_FormOfFilling";
			
			Template = PrintManagement.PrintFormTemplate("Document.InventoryTransfer.PF_MXL_MerchandiseFillingForm", LanguageCode);
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Inventory transfer #%1 dated %2'; ru = 'Перемещение запасов №%1 от %2';pl = 'Przesunięcie międzymagazynowe nr %1 z dn. %2';es_ES = 'Traslado del inventario #%1 fechado %2';es_CO = 'Traslado de inventario #%1 fechado %2';tr = '%1 no.''lu %2 tarihli stok transferi';it = 'Trasferimento di magazzino #%1 datato %2';de = 'Bestandsumlagerung Nr %1 datiert %2'", LanguageCode),
			  	DocumentNumber,
			  	Format(Header.DocumentDate, "DLF=DD"));
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.UseStorageBins.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Date and time of printing: %1. User: %2.'; ru = 'Дата и время печати: %1. Пользователь: %2.';pl = 'Data i godzina wydruku: %1. Użytkownik: %2.';es_ES = 'Fecha y hora de la impresión: %1. Usuario: %2.';es_CO = 'Fecha y hora de la impresión: %1. Usuario: %2.';tr = 'Yazdırma tarihi ve saati: %1. Kullanıcı: %2.';it = 'Data e orario della stampa: %1. Utente: %2';de = 'Datum und Uhrzeit des Drucks: %1. Benutzer: %2.'", LanguageCode),
			  	CurrentSessionDate(),
		  		Users.CurrentUser());
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do
				
				If Not LinesSelectionInventory.ProductsType = Enums.ProductsTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
					LinesSelectionInventory.InventoryItem,
					LinesSelectionInventory.Characteristic,
					LinesSelectionInventory.SKU,
					StringSerialNumbers);
					
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);
			
		ElsIf TemplateName = "MerchandiseFillingFormRecipient" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text =
			"SELECT ALLOWED
			|	InventoryTransfer.Date AS DocumentDate,
			|	InventoryTransfer.StructuralUnitPayee AS WarehousePresentation,
			|	InventoryTransfer.CellPayee AS CellPresentation,
			|	InventoryTransfer.Number,
			|	InventoryTransfer.Company.Prefix AS Prefix,
			|	InventoryTransfer.Inventory.(
			|		LineNumber AS LineNumber,
			|		Products.Warehouse AS Warehouse,
			|		Products.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(InventoryTransfer.Inventory.Products.DescriptionFull AS String(100))) = """"
			|				THEN InventoryTransfer.Inventory.Products.Description
			|			ELSE InventoryTransfer.Inventory.Products.DescriptionFull
			|		END AS InventoryItem,
			|		Products.SKU AS SKU,
			|		Products.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		Products.ProductsType AS ProductsType,
			|		ConnectionKey
			|	),
			|	InventoryTransfer.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.InventoryTransfer AS InventoryTransfer
			|WHERE
			|	InventoryTransfer.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
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
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryTransfer_FormOfFilling";
			
			Template = PrintManagement.PrintFormTemplate("Document.InventoryTransfer.PF_MXL_MerchandiseFillingForm", LanguageCode);
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Inventory transfer #%1 dated %2.'; ru = 'Перемещение запасов №%1 от %2';pl = 'Przesunięcie międzymagazynowe nr %1 z dn. %2.';es_ES = 'Traslado del inventario #%1 fechado %2.';es_CO = 'Traslado de inventario #%1 fechado %2.';tr = '%1 no.''lu %2 tarihli stok transferi';it = 'Trasferimento di magazzino #%1 datato %2.';de = 'Bestandsumlagerung Nr %1 datiert %2.'", LanguageCode),
				DocumentNumber,
			  	Format(Header.DocumentDate, "DLF=DD"));
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.UseStorageBins.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Date and time of printing: %1. User: %2.'; ru = 'Дата и время печати: %1. Пользователь: %2.';pl = 'Data i godzina wydruku: %1. Użytkownik: %2.';es_ES = 'Fecha y hora de la impresión: %1. Usuario: %2.';es_CO = 'Fecha y hora de la impresión: %1. Usuario: %2.';tr = 'Yazdırma tarihi ve saati: %1. Kullanıcı: %2.';it = 'Data e orario della stampa: %1. Utente: %2';de = 'Datum und Uhrzeit des Drucks: %1. Benutzer: %2.'", LanguageCode),
			  	CurrentSessionDate(),
			  	Users.CurrentUser());
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do
				
				If Not LinesSelectionInventory.ProductsType = Enums.ProductsTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
					LinesSelectionInventory.InventoryItem,
					LinesSelectionInventory.Characteristic,
					LinesSelectionInventory.SKU,
					StringSerialNumbers);
					
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);
			
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
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "MerchandiseFillingFormSender") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"MerchandiseFillingFormSender",
			NStr("en = 'Merchandise filling form'; ru = 'Форма заполнения сопутствующих товаров';pl = 'Formularz wypełnienia towaru';es_ES = 'Formulario para rellenar las mercancías';es_CO = 'Formulario para rellenar las mercancías';tr = 'Mamul formu';it = 'Modulo di compilazione merce';de = 'Handelswarenformular'"),
			PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingFormSender", PrintParameters.Result));
		
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "MerchandiseFillingFormRecipient") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"MerchandiseFillingFormRecipient",
			NStr("en = 'Merchandise filling form'; ru = 'Форма заполнения сопутствующих товаров';pl = 'Formularz wypełnienia towaru';es_ES = 'Formulario para rellenar las mercancías';es_CO = 'Formulario para rellenar las mercancías';tr = 'Mamul formu';it = 'Modulo di compilazione merce';de = 'Handelswarenformular'"),
			PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingFormRecipient", PrintParameters.Result));
		
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "Requisition") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"Requisition",
															NStr("en = 'Requisition'; ru = 'Требование';pl = 'Zapotrzebowanie';es_ES = 'Solicitud';es_CO = 'Solicitud';tr = 'Talep formu';it = 'Requisizione';de = 'Anforderung'"),
															DataProcessors.PrintRequisition.PrintForm(ObjectsArray, PrintObjects, "Requisition", PrintParameters.Result));
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "GoodsReceivedNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"GoodsReceivedNote",
															NStr("en = 'Goods received note'; ru = 'Уведомление о доставке товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Nota de recepción de productos';es_CO = 'Nota de recepción de productos';tr = 'Teslim alındı belgesi';it = 'Nota di ricezione merci';de = 'Lieferantenlieferschein'"),
															DataProcessors.PrintGoodsReceivedNote.PrintForm(ObjectsArray, PrintObjects, "GoodsReceivedNote", PrintParameters.Result));
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsReceivedNote";
	PrintCommand.Presentation				= NStr("en = 'Goods received note'; ru = 'Уведомление о доставке товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Nota de la entrega de mercancías';es_CO = 'Nota de recepción de productos';tr = 'Teslim alındı belgesi';it = 'Nota di ricezione merci';de = 'Lieferantenlieferschein'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;

	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingFormSender";
	PrintCommand.Presentation = NStr("en = 'Inventory allocation card (Sender)'; ru = 'Бланк распределения запасов (отправитель)';pl = 'Karta alokacji zapasów (Nadawca)';es_ES = 'Tarjeta de asignación de inventario (Remitente)';es_CO = 'Tarjeta de asignación de inventario (Remitente)';tr = 'Stok dağıtım kartı (Gönderici)';it = 'Scheda allocazione scorte (Mittente)';de = 'Bestandszuordnungskarte (Absender)'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 23;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingFormRecipient";
	PrintCommand.Presentation = NStr("en = 'Inventory allocation card (Recipient)'; ru = 'Бланк распределения запасов (получатель)';pl = 'Karta alokacji zapasów (Odbiorca)';es_ES = 'Tarjeta de asignación de inventario (Destinatario)';es_CO = 'Tarjeta de asignación de inventario (Destinatario)';tr = 'Stok dağıtım kartı (Alıcı)';it = 'Scheda allocazione scorte (Destinatario)';de = 'Bestandszuordnungskarte (Empfänger)'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 26;
	
	If AccessRight("view", Metadata.DataProcessors.PrintLabelsAndTags) Then
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler = "DriveClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID = "LabelsPrintingFromGoodsMovement";
		PrintCommand.Presentation = NStr("en = 'Labels'; ru = 'Этикетки';pl = 'Etykiety';es_ES = 'Etiquetas';es_CO = 'Etiquetas';tr = 'Marka etiketleri';it = 'Etichette';de = 'Etiketten'");
		PrintCommand.FormsList = "DocumentForm,ListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 29;
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler = "DriveClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID = "PriceTagsPrintingFromGoodsMovement";
		PrintCommand.Presentation = NStr("en = 'Price tags'; ru = 'Ценники';pl = 'Cenniki';es_ES = 'Etiquetas de precio';es_CO = 'Etiquetas de precio';tr = 'Fiyat etiketleri';it = 'Cartellini di prezzo';de = 'Preisschilder'");
		PrintCommand.FormsList = "DocumentForm,ListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 32;
		
	EndIf;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Requisition";
	PrintCommand.Presentation				= NStr("en = 'Requisition'; ru = 'Требование';pl = 'Zapotrzebowanie';es_ES = 'Solicitud';es_CO = 'Solicitud';tr = 'Talep formu';it = 'Requisizione';de = 'Anforderung'");
	PrintCommand.FormsList					= "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 33;
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#Region InfobaseUpdate

Procedure ChangeInventoryRecordsForChargeToExpenses() Export
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	InventoryTransfer.Ref AS Ref
	|FROM
	|	Document.InventoryTransfer AS InventoryTransfer
	|		INNER JOIN AccumulationRegister.Inventory AS InventoryRecords
	|		ON InventoryTransfer.Ref = InventoryRecords.Recorder
	|			AND (InventoryRecords.RecordType = VALUE(AccumulationRecordType.Receipt))
	|			AND (InventoryRecords.StructuralUnit = UNDEFINED
	|				OR InventoryRecords.StructuralUnit = VALUE(Catalog.BusinessUnits.EmptyRef))";
	
	QueryResult = Query.Execute();
	
	SelectionDocument = QueryResult.Select();
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	While SelectionDocument.Next() Do
		
		DocumentRef = SelectionDocument.Ref;
		
		BeginTransaction();
		
		Try
			
			DocumentObject = DocumentRef.GetObject();
			
			DriveServer.InitializeAdditionalPropertiesForPosting(DocumentRef, DocumentObject.AdditionalProperties);
			Documents.InventoryTransfer.InitializeDocumentData(DocumentRef, DocumentObject.AdditionalProperties);
			
			DriveServer.ReflectInventory(DocumentObject.AdditionalProperties, DocumentObject.RegisterRecords, False);
			InfobaseUpdate.WriteRecordSet(DocumentObject.RegisterRecords.Inventory);
			
			DocumentObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
			
			InfobaseUpdate.WriteObject(DocumentObject);
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t save %1: %2'; ru = 'Не удалось записать %1:%2';pl = 'Nie udało się zapisać %1: %2';es_ES = 'No se ha podido guardar %1:%2';es_CO = 'No se ha podido guardar %1:%2';tr = '%1 saklanamadı: %2';it = 'Impossibile salvare %1: %2';de = 'Fehler beim Speichern von %1: %2'", DefaultLanguageCode),
				DocumentRef,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Documents.InventoryTransfer,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure FillSalesRecords() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InventoryTransfer.Ref AS Ref
	|FROM
	|	Document.InventoryTransfer AS InventoryTransfer
	|		LEFT JOIN AccumulationRegister.Sales AS Sales
	|		ON InventoryTransfer.Ref = Sales.Recorder
	|WHERE
	|	InventoryTransfer.Posted
	|	AND Sales.Recorder IS NULL
	|	AND InventoryTransfer.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|	AND CASE
	|		WHEN InventoryTransfer.SalesOrder REFS Document.WorkOrder
	|				AND InventoryTransfer.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TRUE
	|		WHEN InventoryTransfer.BasisDocument REFS Document.WorkOrder
	|				AND InventoryTransfer.BasisDocument <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TRUE
	|		ELSE FALSE
	|	END";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocObject = Selection.Ref.GetObject();
		
		BeginTransaction();
		
		Try
			
			DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
			Documents.InventoryTransfer.InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
			
			TableSales = DocObject.AdditionalProperties.TableForRegisterRecords.TableSales;
			
			If Not DocObject.RegisterRecords.Sales.AdditionalProperties.Property("AllowEmptyRecords") Then
				DocObject.RegisterRecords.Sales.AdditionalProperties.Insert("AllowEmptyRecords", DocObject.AdditionalProperties.ForPosting.AllowEmptyRecords);
			EndIf;
			
			DocObject.RegisterRecords.Sales.Write = True;
			DocObject.RegisterRecords.Sales.Load(TableSales);
			InfobaseUpdate.WriteRecordSet(DocObject.RegisterRecords.Sales, True);
			
			DocObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				DocObject.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Documents.InventoryTransfer,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	TableInventory.OperationKind AS OperationKind,
	|	TableInventory.CurrencyPricesRecipient AS CurrencyPricesRecipient,
	|	TableInventory.ExpenseAccountType AS ExpenseAccountType,
	|	TableInventory.CorrActivityDirection AS CorrActivityDirection,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN TableInventory.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|			THEN TableInventory.ExpenseItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END AS CorrIncomeAndExpenseItem,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.TransferOrder.EmptyRef)
	// begin Drive.FullVersion
	|				OR TableInventory.SalesOrder = VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	// end Drive.FullVersion
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN TableInventory.CustomerCorrOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.CustomerCorrOrder = VALUE(Document.WorkOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.TransferOrder.EmptyRef)
	// begin Drive.FullVersion
	|				OR TableInventory.SalesOrder = VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	// end Drive.FullVersion
	|			THEN UNDEFINED
	|		ELSE TableInventory.CustomerCorrOrder
	|	END AS CustomerCorrOrder,
	|	UNDEFINED AS SourceDocument,
	|	UNDEFINED AS CorrSalesOrder,
	|	TableInventory.CorrGLAccount AS AccountDr,
	|	TableInventory.GLAccount AS AccountCr,
	|	TableInventory.RetailTransfer AS RetailTransfer,
	|	TableInventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	TableInventory.ReturnFromRetailEarningAccounting AS ReturnFromRetailEarningAccounting,
	|	TableInventory.MarkupGLAccount AS MarkupGLAccount,
	|	TableInventory.FinancialAccountInRetailRecipient AS FinancialAccountInRetailRecipient,
	|	TableInventory.MarkupGLAccountRecipient AS MarkupGLAccountRecipient,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SUM(CASE
	|			WHEN TableInventory.ReturnFromRetailEarningAccounting
	|				THEN -TableInventory.Quantity
	|			ELSE TableInventory.Quantity
	|		END) AS Quantity,
	|	SUM(CASE
	|			WHEN TableInventory.ReturnFromRetailEarningAccounting
	|				THEN -TableInventory.Reserve
	|			ELSE TableInventory.Reserve
	|		END) AS Reserve,
	|	SUM(CASE
	|			WHEN NOT &FillAmount
	|				THEN 0
	|			WHEN TableInventory.ReturnFromRetailEarningAccounting
	|				THEN -TableInventory.Cost
	|			ELSE TableInventory.Amount
	|		END) AS Amount,
	|	FALSE AS FixedCost,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.OwnershipCorr AS OwnershipCorr,
	|	TableInventory.CostObject AS CostObject
	|INTO SourceTable
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	NOT TableInventory.TransferInRetailEarningAccounting
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.OperationKind,
	|	TableInventory.CurrencyPricesRecipient,
	|	TableInventory.ExpenseAccountType,
	|	TableInventory.CorrActivityDirection,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.ExpenseItem,
	|	TableInventory.GLAccount,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.FinancialAccountInRetailRecipient,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.MarkupGLAccountRecipient,
	|	TableInventory.RetailTransferEarningAccounting,
	|	TableInventory.RetailTransfer,
	|	TableInventory.ReturnFromRetailEarningAccounting,
	|	TableInventory.MarkupGLAccount,
	|	TableInventory.Ownership,
	|	TableInventory.OwnershipCorr,
	|	TableInventory.CostObject,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.GLAccount,
	|	TableInventory.ContentOfAccountingRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SourceTable.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	SourceTable.Period AS Period,
	|	SourceTable.OperationKind AS OperationKind,
	|	SourceTable.CurrencyPricesRecipient AS CurrencyPricesRecipient,
	|	SourceTable.ExpenseAccountType AS ExpenseAccountType,
	|	SourceTable.CorrActivityDirection AS CorrActivityDirection,
	|	SourceTable.Company AS Company,
	|	SourceTable.PresentationCurrency AS PresentationCurrency,
	|	SourceTable.PlanningPeriod AS PlanningPeriod,
	|	SourceTable.StructuralUnit AS StructuralUnit,
	|	SourceTable.StructuralUnitCorr AS StructuralUnitCorr,
	|	SourceTable.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	SourceTable.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	SourceTable.GLAccount AS GLAccount,
	|	SourceTable.InventoryAccountType AS InventoryAccountType,
	|	SourceTable.CorrGLAccount AS CorrGLAccount,
	|	SourceTable.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	SourceTable.Products AS Products,
	|	SourceTable.ProductsCorr AS ProductsCorr,
	|	SourceTable.Characteristic AS Characteristic,
	|	SourceTable.CharacteristicCorr AS CharacteristicCorr,
	|	SourceTable.Batch AS Batch,
	|	SourceTable.BatchCorr AS BatchCorr,
	|	SourceTable.SalesOrder AS SalesOrder,
	|	SourceTable.CustomerCorrOrder AS CustomerCorrOrder,
	|	SourceTable.SourceDocument AS SourceDocument,
	|	SourceTable.CorrSalesOrder AS CorrSalesOrder,
	|	SourceTable.AccountDr AS AccountDr,
	|	SourceTable.AccountCr AS AccountCr,
	|	SourceTable.RetailTransfer AS RetailTransfer,
	|	SourceTable.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	SourceTable.ReturnFromRetailEarningAccounting AS ReturnFromRetailEarningAccounting,
	|	SourceTable.MarkupGLAccount AS MarkupGLAccount,
	|	SourceTable.FinancialAccountInRetailRecipient AS FinancialAccountInRetailRecipient,
	|	SourceTable.MarkupGLAccountRecipient AS MarkupGLAccountRecipient,
	|	SourceTable.Content AS Content,
	|	SourceTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SourceTable.Quantity AS Quantity,
	|	SourceTable.Reserve AS Reserve,
	|	SourceTable.Amount AS Amount,
	|	SourceTable.FixedCost AS FixedCost,
	|	FALSE AS ProductionExpenses,
	|	FALSE AS OfflineRecord,
	|	SourceTable.Ownership AS Ownership,
	|	SourceTable.OwnershipCorr AS OwnershipCorr,
	|	SourceTable.CostObject AS CostObject
	|FROM
	|	SourceTable AS SourceTable
	|
	|UNION ALL
	|
	|SELECT
	|	SourceTable.LineNumber,
	|	VALUE(AccumulationRecordType.Receipt),
	|	SourceTable.Period,
	|	SourceTable.OperationKind,
	|	SourceTable.CurrencyPricesRecipient,
	|	SourceTable.ExpenseAccountType,
	|	SourceTable.CorrActivityDirection,
	|	SourceTable.Company,
	|	SourceTable.PresentationCurrency,
	|	SourceTable.PlanningPeriod,
	|	SourceTable.StructuralUnitCorr,
	|	SourceTable.StructuralUnit,
	|	SourceTable.IncomeAndExpenseItem,
	|	SourceTable.CorrIncomeAndExpenseItem,
	|	SourceTable.CorrGLAccount,
	|	SourceTable.CorrInventoryAccountType,
	|	SourceTable.GLAccount,
	|	SourceTable.InventoryAccountType,
	|	SourceTable.Products,
	|	SourceTable.ProductsCorr,
	|	SourceTable.Characteristic,
	|	SourceTable.CharacteristicCorr,
	|	SourceTable.Batch,
	|	SourceTable.BatchCorr,
	|	SourceTable.SalesOrder,
	|	SourceTable.CustomerCorrOrder,
	|	SourceTable.SourceDocument,
	|	SourceTable.CorrSalesOrder,
	|	SourceTable.AccountDr,
	|	SourceTable.AccountCr,
	|	SourceTable.RetailTransfer,
	|	SourceTable.RetailTransferEarningAccounting,
	|	SourceTable.ReturnFromRetailEarningAccounting,
	|	SourceTable.MarkupGLAccount,
	|	SourceTable.FinancialAccountInRetailRecipient,
	|	SourceTable.MarkupGLAccountRecipient,
	|	SourceTable.Content,
	|	SourceTable.ContentOfAccountingRecord,
	|	SourceTable.Quantity,
	|	SourceTable.Reserve,
	|	SourceTable.Amount,
	|	SourceTable.FixedCost,
	|	FALSE,
	|	FALSE,
	|	SourceTable.Ownership,
	|	SourceTable.OwnershipCorr,
	|	SourceTable.CostObject
	|FROM
	|	SourceTable AS SourceTable
	|		INNER JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON SourceTable.StructuralUnit = BusinessUnits.Ref
	|		INNER JOIN Catalog.BusinessUnits AS BusinessUnitsCorr
	|		ON SourceTable.StructuralUnitCorr = BusinessUnitsCorr.Ref
	|WHERE
	|	NOT &FillAmount
	|	AND (SourceTable.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|			OR SourceTable.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.TransferToOperation)
	|			OR SourceTable.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.ReturnFromExploitation))
	|	AND BusinessUnitsCorr.StructuralUnitType <> VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|	AND BusinessUnits.StructuralUnitType <> VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Period,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	UNDEFINED,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.StructuralUnitCorr,
	|	OfflineRecords.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	OfflineRecords.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.CorrInventoryAccountType,
	|	OfflineRecords.Products,
	|	OfflineRecords.ProductsCorr,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.CharacteristicCorr,
	|	OfflineRecords.Batch,
	|	OfflineRecords.BatchCorr,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.CustomerCorrOrder,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.CorrSalesOrder,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.RetailTransferEarningAccounting,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.Quantity,
	|	UNDEFINED,
	|	OfflineRecords.Amount,
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.ProductionExpenses,
	|	OfflineRecords.OfflineRecord,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.OwnershipCorr,
	|	OfflineRecords.CostObject
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableInventory.InventoryAccountType AS InventoryAccountType,
	|	TemporaryTableInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableInventory.GLAccount AS GLAccount,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	TemporaryTableInventory.Ownership AS Ownership,
	|	TemporaryTableInventory.CostObject AS CostObject,
	|	TemporaryTableInventory.Work AS Work,
	|	TemporaryTableInventory.WorkCharacteristic AS WorkCharacteristic,
	|	SUM(TemporaryTableInventory.Quantity) AS Quantity,
	|	0 AS Amount
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|WHERE
	|	NOT TemporaryTableInventory.TransferInRetailEarningAccounting
	|	AND &PostExpensesByInventoryTransfer
	|	AND TemporaryTableInventory.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|	AND CASE
	|		WHEN TemporaryTableInventory.SalesOrder REFS Document.WorkOrder
	|				AND TemporaryTableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TRUE
	|		WHEN TemporaryTableInventory.WorkOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TRUE
	|		ELSE FALSE
	|	END
	|
	|GROUP BY
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.PresentationCurrency,
	|	TemporaryTableInventory.InventoryAccountType,
	|	TemporaryTableInventory.GLAccount,
	|	TemporaryTableInventory.Products,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Batch,
	|	TemporaryTableInventory.Ownership,
	|	TemporaryTableInventory.CostObject,
	|	TemporaryTableInventory.StructuralUnit,
	|	TemporaryTableInventory.Work,
	|	TemporaryTableInventory.WorkCharacteristic";
	
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	Query.SetParameter("FillAmount", FillAmount);
	Query.SetParameter("Ref", DocumentRefInventoryTransfer);
	Query.SetParameter("PostExpensesByInventoryTransfer", Not StructureAdditionalProperties.AccountingPolicy.PostExpensesByWorkOrder);
	
	QueryResult = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableConsumersInventoryForSales", QueryResult[2].Unload());
	
	If FillAmount Or StructureAdditionalProperties.TableForRegisterRecords.TableConsumersInventoryForSales.Count() Then
		FillAmountInInventoryTable(DocumentRefInventoryTransfer, StructureAdditionalProperties, FillAmount);
	EndIf;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableTransferOrders(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableTransferOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableTransferOrders.Period AS Period,
	|	TableTransferOrders.Company AS Company,
	|	TableTransferOrders.Products AS Products,
	|	TableTransferOrders.Characteristic AS Characteristic,
	|	TableTransferOrders.SalesOrder AS TransferOrder,
	|	SUM(TableTransferOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableTransferOrders
	|WHERE
	|	VALUETYPE(TableTransferOrders.SalesOrder) = TYPE(Document.TransferOrder)
	|	AND TableTransferOrders.SalesOrder <> VALUE(Document.TransferOrder.EmptyRef)
	|
	|GROUP BY
	|	TableTransferOrders.Period,
	|	TableTransferOrders.Company,
	|	TableTransferOrders.Products,
	|	TableTransferOrders.Characteristic,
	|	TableTransferOrders.SalesOrder";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTransferOrders", QueryResult.Unload());
	
EndProcedure

Procedure FillAmountInInventoryTable(DocumentRefInventoryTransfer, StructureAdditionalProperties, FillAmount)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CostObject AS CostObject
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	NOT TableInventory.TransferInRetailEarningAccounting
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.StructuralUnit,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.CostObject";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.Ownership AS Ownership,
	|	InventoryBalances.CostObject AS CostObject,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.Ownership AS Ownership,
	|		InventoryBalances.CostObject AS CostObject,
	|		InventoryBalances.QuantityBalance AS QuantityBalance,
	|		InventoryBalances.AmountBalance AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.PresentationCurrency,
	|						TableInventory.StructuralUnit,
	|						TableInventory.InventoryAccountType,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.Ownership,
	|						TableInventory.CostObject
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						NOT TableInventory.TransferInRetailEarningAccounting)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.PresentationCurrency,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.InventoryAccountType,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		DocumentRegisterRecordsInventory.Ownership,
	|		DocumentRegisterRecordsInventory.CostObject,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.PresentationCurrency,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.InventoryAccountType,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.Ownership,
	|	InventoryBalances.CostObject";
	
	Query.SetParameter("Ref", DocumentRefInventoryTransfer);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add(
		"Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	If UseDefaultTypeOfAccounting Then
		EmptyAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EndIf;
	
	IsEmptyStructuralUnit = Catalogs.BusinessUnits.EmptyRef();
	EmptyInventoryAccountType = Enums.InventoryAccountTypes.EmptyRef();
	EmptyProducts = Undefined;
	EmptyCharacteristic = Catalogs.ProductsCharacteristics.EmptyRef();
	EmptyBatch = Catalogs.ProductsBatches.EmptyRef();
	EmptyOwnership = Catalogs.InventoryOwnership.EmptyRef();
	EmptySalesOrder = Undefined;
	EmptyIncomeAndExpenseItem = Catalogs.IncomeAndExpenseItems.EmptyRef();
	ManufacturingOverheads = Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads;
	
	RetailTransferEarningAccounting = False;
	ReturnFromRetailEarningAccounting = False;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		If FillAmount And RowTableInventory.ReturnFromRetailEarningAccounting Then
			
			ReturnFromRetailEarningAccounting = True;
			
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			TableRowExpense.StructuralUnit = TableRowExpense.StructuralUnitCorr;
			TableRowExpense.StructuralUnitCorr = Undefined;
			TableRowExpense.CorrGLAccount = Undefined;
			TableRowExpense.CorrInventoryAccountType = Undefined;
			TableRowExpense.ProductsCorr = Undefined;
			TableRowExpense.CharacteristicCorr = Undefined;
			TableRowExpense.BatchCorr = Undefined;
			TableRowExpense.OwnershipCorr = Undefined;
			TableRowExpense.CustomerCorrOrder = Undefined;
			TableRowExpense.FixedCost = True;
			
			If UseDefaultTypeOfAccounting Then
				
				RowTableAccountingJournalEntries = 
					StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.Amount = RowTableInventory.Amount;
				RowTableAccountingJournalEntries.AccountDr = RowTableInventory.GLAccount;
				
			EndIf;
			
			Continue;
			
		EndIf;
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("PresentationCurrency", RowTableInventory.PresentationCurrency);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("InventoryAccountType", RowTableInventory.InventoryAccountType);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		StructureForSearch.Insert("Ownership", RowTableInventory.Ownership);
		StructureForSearch.Insert("CostObject", RowTableInventory.CostObject);
		
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 And QuantityBalance > QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then
				
				AmountToBeWrittenOff = AmountBalance;
				
				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			If FillAmount Then
				
				// Expense.
				TableRowExpense = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowExpense, RowTableInventory);
				
				TableRowExpense.Amount = AmountToBeWrittenOff;
				TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
				TableRowExpense.SalesOrder = EmptySalesOrder;
				
				If ValueIsFilled(TableRowExpense.CustomerCorrOrder)
					AND TypeOf(TableRowExpense.CustomerCorrOrder) = Type("DocumentRef.SalesOrder") Then
					
					TableRowExpense.CustomerCorrOrder = EmptySalesOrder;
					
				EndIf;
				
				IncomeAndExpenseType = Common.ObjectAttributeValue(RowTableInventory.CorrIncomeAndExpenseItem, "IncomeAndExpenseType");
				
				If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses
					Or IncomeAndExpenseType = ManufacturingOverheads Then
					
					TableRowExpense.SourceDocument = DocumentRefInventoryTransfer;
					
				Else
					
					If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer
						And RowTableInventory.RetailTransfer Then
						
						TableRowExpense.CustomerCorrOrder = EmptySalesOrder;
						
					ElsIf Not RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer
						And Not IncomeAndExpenseType = ManufacturingOverheads Then
						
						TableRowExpense.CustomerCorrOrder = EmptySalesOrder;
						
					EndIf;
					
				EndIf;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 And UseDefaultTypeOfAccounting Then
					
					RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
					RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
					
					If RowTableInventory.RetailTransferEarningAccounting Then
						RowTableAccountingJournalEntries.AccountDr = RowTableInventory.FinancialAccountInRetailRecipient;
					EndIf;
					
				EndIf;
				
				If RowTableInventory.RetailTransferEarningAccounting Then
					
					StringTablePOSSummary = StructureAdditionalProperties.TableForRegisterRecords.TablePOSSummary.Add();
					FillPropertyValues(StringTablePOSSummary, RowTableInventory);
					StringTablePOSSummary.RecordType = AccumulationRecordType.Receipt;
					StringTablePOSSummary.Cost = AmountToBeWrittenOff;
					StringTablePOSSummary.Currency = RowTableInventory.CurrencyPricesRecipient;
					StringTablePOSSummary.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					StringTablePOSSummary.Amount = 0;
					StringTablePOSSummary.AmountCur = 0;
					
					RetailTransferEarningAccounting = True;
					
				ElsIf Round(AmountToBeWrittenOff, 2, 1) <> 0 Or QuantityRequiredAvailableBalance > 0 Then // Receipt
					
					If IncomeAndExpenseType = ManufacturingOverheads Then
						
						TableRowReceipt = TemporaryTableInventory.Add();
						
						If UseDefaultTypeOfAccounting Then
							TableRowReceipt.CorrGLAccount = EmptyAccount;
						EndIf;
						
						FillPropertyValues(TableRowReceipt, RowTableInventory);
						TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
						TableRowReceipt.Company = RowTableInventory.Company;
						TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
						TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
						TableRowReceipt.CorrGLAccount = Undefined;
						TableRowReceipt.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
						TableRowReceipt.CorrInventoryAccountType = EmptyInventoryAccountType;
						TableRowReceipt.Products = RowTableInventory.ProductsCorr;
						TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
						TableRowReceipt.Batch = RowTableInventory.BatchCorr;
						TableRowReceipt.Ownership = RowTableInventory.OwnershipCorr;
						TableRowReceipt.ProductionExpenses = True;
						TableRowReceipt.Amount = AmountToBeWrittenOff;
						TableRowReceipt.Quantity = 0;
						TableRowReceipt.StructuralUnitCorr = IsEmptyStructuralUnit;
						TableRowReceipt.CorrInventoryAccountType = EmptyInventoryAccountType;
						TableRowReceipt.ProductsCorr = EmptyProducts;
						TableRowReceipt.CharacteristicCorr = EmptyCharacteristic;
						TableRowReceipt.BatchCorr = EmptyBatch;
						TableRowReceipt.OwnershipCorr = EmptyOwnership;
						TableRowReceipt.CustomerCorrOrder = EmptySalesOrder;
						TableRowReceipt.IncomeAndExpenseItem = RowTableInventory.CorrIncomeAndExpenseItem;
						TableRowReceipt.CorrIncomeAndExpenseItem = EmptyIncomeAndExpenseItem;
						
					ElsIf RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses Then
						
						StringTablesTurnover = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
						FillPropertyValues(StringTablesTurnover, RowTableInventory);
						StringTablesTurnover.StructuralUnit = RowTableInventory.StructuralUnitCorr;
						StringTablesTurnover.BusinessLine = RowTableInventory.CorrActivityDirection;
						
						If ValueIsFilled(DocumentRefInventoryTransfer.BasisDocument)
							AND TypeOf(DocumentRefInventoryTransfer.BasisDocument) = Type("DocumentRef.WorkOrder") Then
							
							StringTablesTurnover.SalesOrder = DocumentRefInventoryTransfer.BasisDocument;
							
						ElsIf TypeOf(RowTableInventory.CustomerCorrOrder) = Type("DocumentRef.TransferOrder") Then
							StringTablesTurnover.SalesOrder = Common.ObjectAttributeValue(RowTableInventory.CustomerCorrOrder, "SalesOrder");
						Else
							StringTablesTurnover.SalesOrder = RowTableInventory.CustomerCorrOrder;
						EndIf;
						
						StringTablesTurnover.AmountExpense = AmountToBeWrittenOff;
						StringTablesTurnover.GLAccount = RowTableInventory.CorrGLAccount;
						StringTablesTurnover.IncomeAndExpenseItem = RowTableInventory.CorrIncomeAndExpenseItem;
						
					Else // These are costs.
						
						TableRowReceipt = TemporaryTableInventory.Add();
						FillPropertyValues(TableRowReceipt, RowTableInventory);
						
						TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
						
						TableRowReceipt.Company = RowTableInventory.Company;
						TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
						TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
						TableRowReceipt.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
						TableRowReceipt.Products = RowTableInventory.ProductsCorr;
						TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
						TableRowReceipt.Batch = RowTableInventory.BatchCorr;
						TableRowReceipt.Ownership = RowTableInventory.OwnershipCorr;
						TableRowReceipt.IncomeAndExpenseItem = RowTableInventory.CorrIncomeAndExpenseItem;
						
						If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer
							AND Not RowTableInventory.RetailTransfer Then
							
							TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
							
						Else
							TableRowReceipt.SalesOrder = EmptySalesOrder;
						EndIf;
						
						If ValueIsFilled(TableRowReceipt.SalesOrder)
							AND TypeOf(TableRowReceipt.SalesOrder) = Type("DocumentRef.SalesOrder") Then
							
							TableRowReceipt.SalesOrder = EmptySalesOrder;
							
						EndIf;
						
						TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
						TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
						TableRowReceipt.CorrInventoryAccountType = RowTableInventory.InventoryAccountType;
						TableRowReceipt.ProductsCorr = RowTableInventory.Products;
						TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
						TableRowReceipt.BatchCorr = RowTableInventory.Batch;
						TableRowReceipt.OwnershipCorr = RowTableInventory.Ownership;
						TableRowReceipt.CustomerCorrOrder = EmptySalesOrder;
						TableRowReceipt.CorrIncomeAndExpenseItem = RowTableInventory.IncomeAndExpenseItem;
						
						TableRowReceipt.Amount = AmountToBeWrittenOff;
						TableRowReceipt.Quantity = QuantityRequiredAvailableBalance;
						
						If RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation
							Or RowTableInventory.OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation Then
							
							If UseDefaultTypeOfAccounting Then
								TableRowReceipt.CorrGLAccount = EmptyAccount;
							EndIf;
							
							TableRowReceipt.StructuralUnitCorr = IsEmptyStructuralUnit;
							TableRowReceipt.CorrInventoryAccountType = EmptyInventoryAccountType;
							TableRowReceipt.ProductsCorr = EmptyProducts;
							TableRowReceipt.CharacteristicCorr = EmptyCharacteristic;
							TableRowReceipt.BatchCorr = EmptyBatch;
							TableRowReceipt.OwnershipCorr = EmptyOwnership;
							TableRowReceipt.CustomerCorrOrder = EmptySalesOrder;
							
						EndIf;
						
					EndIf;
					
				EndIf;
				
			EndIf;
		
			// Fill TableConsumersInventoryForSales
			ConsumersInventoryForSalesArray =
				StructureAdditionalProperties.TableForRegisterRecords.TableConsumersInventoryForSales.FindRows(StructureForSearch);
			For Each ConsumersInventoryForSalesLine In ConsumersInventoryForSalesArray Do
			
				If QuantityBalance > 0 And QuantityBalance > ConsumersInventoryForSalesLine.Quantity Then
					
					ConsumersInventoryForSalesLine.Amount = Round(AmountBalance * ConsumersInventoryForSalesLine.Quantity / QuantityBalance , 2, 1);
					
				ElsIf QuantityBalance = ConsumersInventoryForSalesLine.Quantity Then
					
					ConsumersInventoryForSalesLine.Amount = AmountBalance;
					
				Else
					
					ConsumersInventoryForSalesLine.Amount = 0;
					
				EndIf
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	If FillAmount Then
		
		StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
		
		// Retail markup (amount accounting).
		If RetailTransferEarningAccounting
			Or ReturnFromRetailEarningAccounting Then
			
			SumCost = TemporaryTableInventory.Total("Amount");
			
			Query = New Query;
			Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
			Query.Text =
			"SELECT
			|	SUM(ISNULL(TemporaryTablePOSSummary.Amount, 0)) AS Amount
			|FROM
			|	TemporaryTablePOSSummary AS TemporaryTablePOSSummary";
			
			SelectionOfQueryResult = Query.Execute().Select();
			
			If SelectionOfQueryResult.Next() Then
				SumInSalesPrices = SelectionOfQueryResult.Amount;
			Else
				SumInSalesPrices = 0;
			EndIf;
			
			AmountMarkup = SumInSalesPrices - SumCost;
			
			If AmountMarkup <> 0 Then
				
				If TemporaryTableInventory.Count() > 0 Then
					TableRow = TemporaryTableInventory[0];
				ElsIf StructureAdditionalProperties.TableForRegisterRecords.TablePOSSummary.Count() > 0 Then
					TableRow = StructureAdditionalProperties.TableForRegisterRecords.TablePOSSummary[0];
				Else
					TableRow = Undefined;
				EndIf;
				
				If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting And TableRow <> Undefined Then
					
					RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRow);
					RowTableAccountingJournalEntries.AccountDr = ?(RetailTransferEarningAccounting, TableRow.FinancialAccountInRetailRecipient, TableRow.GLAccount);
					RowTableAccountingJournalEntries.AccountCr = ?(RetailTransferEarningAccounting, TableRow.MarkupGLAccountRecipient, TableRow.MarkupGLAccount);
					RowTableAccountingJournalEntries.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					RowTableAccountingJournalEntries.Content = NStr("en = 'Retail markup'; ru = 'Торговая наценка';pl = 'Marża detaliczna';es_ES = 'Marca de la venta al por menor';es_CO = 'Marca de la venta al por menor';tr = 'Perakende kâr marjı';it = 'Margine di vendita al dettaglio';de = 'Einzelhandels-Aufschlag'");
					RowTableAccountingJournalEntries.Amount = AmountMarkup;
					
				EndIf;
				
			EndIf;
		
		EndIf;
		
	EndIf;

EndProcedure

Procedure GenerateTableSales(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableConsumersInventoryForSales.Products AS Products,
	|	TableConsumersInventoryForSales.Characteristic AS Characteristic,
	|	TableConsumersInventoryForSales.Batch AS Batch,
	|	TableConsumersInventoryForSales.InventoryAccountType AS InventoryAccountType,
	|	TableConsumersInventoryForSales.CostObject AS CostObject,
	|	TableConsumersInventoryForSales.Work AS Work,
	|	TableConsumersInventoryForSales.WorkCharacteristic AS WorkCharacteristic,
	|	TableConsumersInventoryForSales.Quantity AS Quantity,
	|	TableConsumersInventoryForSales.Amount AS Amount
	|INTO TableConsumersInventoryForSales
	|FROM
	|	&TableConsumersInventoryForSales AS TableConsumersInventoryForSales
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.PresentationCurrency AS PresentationCurrency,
	|	DocumentWorkOrder.Counterparty AS Counterparty,
	|	DocumentWorkOrder.DocumentCurrency AS Currency,
	|	TemporaryTableInventory.Work AS Products,
	|	TemporaryTableInventory.WorkCharacteristic AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	&OwnInventory AS Ownership,
	|	CASE
	|		WHEN TemporaryTableInventory.SalesOrder REFS Document.WorkOrder
	|				AND TemporaryTableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TemporaryTableInventory.SalesOrder
	|		ELSE TemporaryTableInventory.WorkOrder
	|	END AS SalesOrder,
	|	TemporaryTableInventory.Document AS Document,
	|	ISNULL(CatalogProducts.VATRate, VALUE(Catalog.VATRates.EmptyRef)) AS VATRate,
	|	TemporaryTableInventory.StructuralUnit AS Department,
	|	DocumentWorkOrder.Responsible AS Responsible,
	|	0 AS Quantity,
	|	0 AS VATAmount,
	|	0 AS Amount,
	|	0 AS VATAmountCur,
	|	0 AS AmountCur,
	|	0 AS SalesTaxAmount,
	|	0 AS SalesTaxAmountCur,
	|	SUM(TableConsumersInventoryForSales.Amount) AS Cost,
	|	FALSE AS OfflineRecord,
	|	DocumentWorkOrder.SalesRep AS SalesRep,
	|	NULL AS BundleProduct,
	|	NULL AS BundleCharacteristic,
	|	DocumentWorkOrder.Start AS DeliveryStartDate,
	|	DocumentWorkOrder.Finish AS DeliveryEndDate,
	|	FALSE AS ZeroInvoice
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TableConsumersInventoryForSales AS TableConsumersInventoryForSales
	|		ON TemporaryTableInventory.Work = TableConsumersInventoryForSales.Work
	|			AND TemporaryTableInventory.WorkCharacteristic = TableConsumersInventoryForSales.WorkCharacteristic
	|			AND TemporaryTableInventory.Products = TableConsumersInventoryForSales.Products
	|			AND TemporaryTableInventory.Characteristic = TableConsumersInventoryForSales.Characteristic
	|			AND TemporaryTableInventory.Batch = TableConsumersInventoryForSales.Batch
	|			AND TemporaryTableInventory.InventoryAccountType = TableConsumersInventoryForSales.InventoryAccountType
	|			AND TemporaryTableInventory.CostObject = TableConsumersInventoryForSales.CostObject
	|		INNER JOIN Document.WorkOrder AS DocumentWorkOrder
	|		ON TemporaryTableInventory.SalesOrder = DocumentWorkOrder.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TemporaryTableInventory.Work = CatalogProducts.Ref
	|WHERE
	|	TableConsumersInventoryForSales.Amount > 0
	|
	|GROUP BY
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.PresentationCurrency,
	|	DocumentWorkOrder.Counterparty,
	|	DocumentWorkOrder.DocumentCurrency,
	|	DocumentWorkOrder.Responsible,
	|	DocumentWorkOrder.SalesRep,
	|	TemporaryTableInventory.Work,
	|	TemporaryTableInventory.WorkCharacteristic,
	|	TemporaryTableInventory.StructuralUnit,
	|	TemporaryTableInventory.Document,
	|	CASE
	|		WHEN TemporaryTableInventory.SalesOrder REFS Document.WorkOrder
	|				AND TemporaryTableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TemporaryTableInventory.SalesOrder
	|		ELSE TemporaryTableInventory.WorkOrder
	|	END,
	|	DocumentWorkOrder.Start,
	|	DocumentWorkOrder.Finish,
	|	ISNULL(CatalogProducts.VATRate, VALUE(Catalog.VATRates.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT
	|	TableSales.Period,
	|	TableSales.Company,
	|	TableSales.PresentationCurrency,
	|	TableSales.Counterparty,
	|	TableSales.Currency,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.Ownership,
	|	TableSales.SalesOrder,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.Department,
	|	TableSales.Responsible,
	|	TableSales.Quantity,
	|	TableSales.VATAmount,
	|	TableSales.Amount,
	|	TableSales.VATAmountCur,
	|	TableSales.AmountCur,
	|	TableSales.SalesTaxAmount,
	|	TableSales.SalesTaxAmountCur,
	|	TableSales.Cost,
	|	TableSales.OfflineRecord,
	|	TableSales.SalesRep,
	|	TableSales.BundleProduct,
	|	TableSales.BundleCharacteristic,
	|	TableSales.DeliveryStartDate,
	|	TableSales.DeliveryEndDate,
	|	TableSales.ZeroInvoice
	|FROM
	|	AccumulationRegister.Sales AS TableSales
	|WHERE
	|	TableSales.Recorder = &Ref
	|	AND TableSales.OfflineRecord";
	
	Query.SetParameter("TableConsumersInventoryForSales", StructureAdditionalProperties.TableForRegisterRecords.TableConsumersInventoryForSales);
	Query.SetParameter("Ref", DocumentRefInventoryTransfer);
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
	StructureAdditionalProperties.ForPosting.AllowEmptyRecords = True;
	
EndProcedure

Procedure GenerateTableReservedProducts(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT DISTINCT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS SalesOrder
	|INTO ReservedProducts
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	(VALUETYPE(TableInventory.SalesOrder) = TYPE(Document.TransferOrder)
	|				AND TableInventory.SalesOrder <> VALUE(Document.TransferOrder.EmptyRef)
	|			Or VALUETYPE(TableInventory.SalesOrder) = TYPE(Document.WorkOrder)
	|				AND TableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			Or &ProductionTypeIsFilledConditionText
	|			Or TableInventory.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|				AND VALUETYPE(TableInventory.SalesOrder) = TYPE(Document.SalesOrder)
	|				AND TableInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS SalesOrder
	|FROM
	|	ReservedProducts AS TableInventory";
	
	ProductionTypeIsFilledConditionText = "FALSE";
	// begin Drive.FullVersion
	ProductionTypeIsFilledConditionText = "VALUETYPE(TableInventory.SalesOrder) = TYPE(Document.ProductionOrder)
	|		AND TableInventory.SalesOrder <> VALUE(Document.ProductionOrder.EmptyRef)
	|	Or VALUETYPE(TableInventory.SalesOrder) = TYPE(Document.ManufacturingOperation)
	|		AND TableInventory.SalesOrder <> VALUE(Document.ManufacturingOperation.EmptyRef)";
	// end Drive.FullVersion
	
	Query.Text = StrReplace(Query.Text, "&ProductionTypeIsFilledConditionText", ProductionTypeIsFilledConditionText);
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.ReservedProducts");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	"SELECT
	|	Balance.Company AS Company,
	|	Balance.StructuralUnit AS StructuralUnit,
	|	Balance.Products AS Products,
	|	Balance.Characteristic AS Characteristic,
	|	Balance.Batch AS Batch,
	|	Balance.SalesOrder AS SalesOrder,
	|	SUM(Balance.Quantity) AS Quantity
	|INTO ReservedProductsBalance
	|FROM
	|	(SELECT
	|		Balance.Company AS Company,
	|		Balance.StructuralUnit AS StructuralUnit,
	|		Balance.Products AS Products,
	|		Balance.Characteristic AS Characteristic,
	|		Balance.Batch AS Batch,
	|		Balance.SalesOrder AS SalesOrder,
	|		Balance.QuantityBalance AS Quantity
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						ReservedProducts.Company AS Company,
	|						ReservedProducts.StructuralUnit AS StructuralUnit,
	|						ReservedProducts.Products AS Products,
	|						ReservedProducts.Characteristic AS Characteristic,
	|						ReservedProducts.Batch AS Batch,
	|						ReservedProducts.SalesOrder AS SalesOrder
	|					FROM
	|						ReservedProducts AS ReservedProducts)) AS Balance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsReservedProducts.Company,
	|		DocumentRegisterRecordsReservedProducts.StructuralUnit,
	|		DocumentRegisterRecordsReservedProducts.Products,
	|		DocumentRegisterRecordsReservedProducts.Characteristic,
	|		DocumentRegisterRecordsReservedProducts.Batch,
	|		DocumentRegisterRecordsReservedProducts.SalesOrder,
	|		CASE
	|			WHEN DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsReservedProducts.Quantity
	|			ELSE -DocumentRegisterRecordsReservedProducts.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.Period <= &ControlPeriod) AS Balance
	|
	|GROUP BY
	|	Balance.StructuralUnit,
	|	Balance.Company,
	|	Balance.Batch,
	|	Balance.Characteristic,
	|	Balance.Products,
	|	Balance.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	SUM(TableInventory.Reserve) AS Reserve
	|INTO TemporaryTableInventoryGrouped
	|FROM
	|	(SELECT
	|		TableInventory.Period AS Period,
	|		TableInventory.Company AS Company,
	|		TableInventory.StructuralUnit AS StructuralUnit,
	|		TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|		TableInventory.GLAccount AS GLAccount,
	|		TableInventory.Products AS Products,
	|		TableInventory.Characteristic AS Characteristic,
	|		TableInventory.Batch AS Batch,
	|		TableInventory.SalesOrder AS SalesOrder,
	|		TableInventory.Reserve AS Reserve
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		(VALUETYPE(TableInventory.SalesOrder) = TYPE(Document.TransferOrder)
	|					AND TableInventory.SalesOrder <> VALUE(Document.TransferOrder.EmptyRef)
	|				OR VALUETYPE(TableInventory.SalesOrder) = TYPE(Document.WorkOrder)
	|					AND TableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|				OR &ProductionTypeIsFilledConditionText)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableInventory.Period,
	|		TableInventory.Company,
	|		TableInventory.StructuralUnit,
	|		TableInventory.StructuralUnitCorr,
	|		TableInventory.GLAccount,
	|		TableInventory.Products,
	|		TableInventory.Characteristic,
	|		TableInventory.Batch,
	|		TableInventory.SalesOrder,
	|		TableInventory.Reserve
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		TableInventory.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
	|		AND VALUETYPE(TableInventory.SalesOrder) = TYPE(Document.SalesOrder)
	|		AND TableInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)) AS TableInventory
	|
	|GROUP BY
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.Company,
	|	TableInventory.SalesOrder,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Products,
	|	TableInventory.Period,
	|	TableInventory.GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	CASE
	|		WHEN Balance.Quantity > TableInventory.Reserve
	|			THEN TableInventory.Reserve
	|		ELSE Balance.Quantity
	|	END AS Quantity
	|INTO AvailableReserve
	|FROM
	|	TemporaryTableInventoryGrouped AS TableInventory
	|		INNER JOIN ReservedProductsBalance AS Balance
	|		ON TableInventory.Company = Balance.Company
	|			AND TableInventory.StructuralUnit = Balance.StructuralUnit
	|			AND TableInventory.Products = Balance.Products
	|			AND TableInventory.Characteristic = Balance.Characteristic
	|			AND TableInventory.Batch = Balance.Batch
	|			AND TableInventory.SalesOrder = Balance.SalesOrder
	|WHERE
	|	TableInventory.Reserve > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	Reserve.Period AS Period,
	|	Reserve.Company AS Company,
	|	Reserve.StructuralUnit AS StructuralUnit,
	|	Reserve.GLAccount AS GLAccount,
	|	Reserve.Products AS Products,
	|	Reserve.Characteristic AS Characteristic,
	|	Reserve.Batch AS Batch,
	|	Reserve.SalesOrder AS SalesOrder,
	|	Reserve.Quantity AS Quantity
	|FROM
	|	AvailableReserve AS Reserve
	|WHERE
	|	Reserve.Quantity > 0
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	Reserve.Period,
	|	Reserve.Company,
	|	Reserve.StructuralUnitCorr,
	|	Reserve.GLAccount,
	|	Reserve.Products,
	|	Reserve.Characteristic,
	|	Reserve.Batch,
	|	Reserve.SalesOrder,
	|	Reserve.Quantity
	|FROM
	|	AvailableReserve AS Reserve
	|WHERE
	|	Reserve.Quantity > 0
	|	AND (VALUETYPE(Reserve.SalesOrder) = TYPE(Document.SalesOrder) OR &ProductionTypeConditionText)";
	
	Query.Text = StrReplace(Query.Text, "&ProductionTypeIsFilledConditionText", ProductionTypeIsFilledConditionText);
	
	ProductionTypeConditionText = "FALSE";
	// begin Drive.FullVersion
	ProductionTypeConditionText = "VALUETYPE(Reserve.SalesOrder) = TYPE(Document.ProductionOrder)
	|	OR VALUETYPE(Reserve.SalesOrder) = TYPE(Document.ManufacturingOperation)";
	// end Drive.FullVersion
	
	Query.Text = StrReplace(Query.Text, "&ProductionTypeConditionText", ProductionTypeConditionText);
	
	Query.SetParameter("Ref", DocumentRefInventoryTransfer);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Cell AS Cell,
	|	TableInventory.Company AS Company,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Quantity AS Quantity,
	|	TableInventory.Ownership AS Ownership
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	NOT TableInventory.ReturnFromRetailEarningAccounting
	|	AND NOT TableInventory.TransferInRetailEarningAccounting
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventory.LineNumber,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableInventory.Period,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.CorrCell,
	|	TableInventory.Company,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.BatchCorr,
	|	TableInventory.Quantity,
	|	TableInventory.Ownership
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	NOT TableInventory.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|	AND NOT TableInventory.RetailTransferEarningAccounting
	|	AND NOT TableInventory.TransferInRetailEarningAccounting";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableWorkOrders(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableWorkOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableWorkOrders.Period AS Period,
	|	TableWorkOrders.Company AS Company,
	|	TableWorkOrders.Products AS Products,
	|	TableWorkOrders.Characteristic AS Characteristic,
	|	TableWorkOrders.WorkOrder AS WorkOrder,
	|	SUM(TableWorkOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableWorkOrders
	|WHERE
	|	TableWorkOrders.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|	AND VALUETYPE(TableWorkOrders.WorkOrder) = TYPE(Document.WorkOrder)
	|	AND TableWorkOrders.WorkOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|
	|GROUP BY
	|	TableWorkOrders.Period,
	|	TableWorkOrders.Company,
	|	TableWorkOrders.Products,
	|	TableWorkOrders.Characteristic,
	|	TableWorkOrders.WorkOrder";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkOrders", New ValueTable);
		
	Else
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkOrders", QueryResult.Unload());
		
	EndIf;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("FXIncomeItem",					Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem",				Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("Ref",							DocumentRefInventoryTransfer);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND Header.OperationKind <> VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
	|		INNER JOIN Header AS Header
	|		ON (TRUE)
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePOSSummary(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",					DocumentRefInventoryTransfer);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("RetailTransfer",		NStr("en = 'Move to retail'; ru = 'Перемещение в розницу';pl = 'Przeniesienie do sprzedaży detalicznej';es_ES = 'Mover a la venta al por menor';es_CO = 'Mover a la venta al por menor';tr = 'Perakendeye geç';it = 'Spostare alla vendita al dettaglio';de = 'In den Einzelhandel wechseln'", MainLanguageCode));
	Query.SetParameter("RetailTransfer",		NStr("en = 'Movement in retail'; ru = 'Перемещение в рознице';pl = 'Przemieszczenie w detalu';es_ES = 'Movimiento a la venta al por menor';es_CO = 'Movimiento a la venta al por menor';tr = 'Perakendede hareket';it = 'Spostamento nella vendita al dettaglio';de = 'Bewegung im Einzelhandel'", MainLanguageCode));
	Query.SetParameter("ReturnAndRetail",		NStr("en = 'Return from retail'; ru = 'Возврат из розницы';pl = 'Zwrot z detalu';es_ES = 'Devolución de la venta al por menor';es_CO = 'Devolución de la venta al por menor';tr = 'Perakende satıştan iade';it = 'Restituzione dalla vendita al dettaglio';de = 'Rückkehr aus dem Einzelhandel'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Date,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.RetailPriceKind AS RetailPriceKind,
	|	DocumentTable.Products AS Products,
	|	DocumentTable.Characteristic AS Characteristic,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.SalesOrder AS SalesOrder,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.AmountCur AS AmountCur,
	|	DocumentTable.Amount AS AmountForBalance,
	|	DocumentTable.AmountCur AS AmountCurForBalance,
	|	DocumentTable.Cost AS Cost,
	|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
	|INTO TemporaryTablePOSSummary
	|FROM
	|	(SELECT
	|		DocumentTable.Period AS Date,
	|		VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|		DocumentTable.LineNumber AS LineNumber,
	|		DocumentTable.Company AS Company,
	|		DocumentTable.PresentationCurrency AS PresentationCurrency,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN DocumentTable.RetailPriceKind
	|			ELSE DocumentTable.RetailPriceKindRecipient
	|		END AS RetailPriceKind,
	|		DocumentTable.Products AS Products,
	|		DocumentTable.Characteristic AS Characteristic,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN DocumentTable.StructuralUnit
	|			ELSE DocumentTable.StructuralUnitCorr
	|		END AS StructuralUnit,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN DocumentTable.PriceCurrency
	|			ELSE DocumentTable.CurrencyPricesRecipient
	|		END AS Currency,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN DocumentTable.GLAccount
	|			ELSE DocumentTable.FinancialAccountInRetailRecipient
	|		END AS GLAccount,
	|		DocumentTable.SalesOrder AS SalesOrder,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN -(CAST(PricesSliceLast.Price * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentTable.Quantity * CurrencyPriceExchangeRate.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRate.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (DocumentTable.Quantity * CurrencyPriceExchangeRate.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRate.Repetition)) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1)
	|						END AS NUMBER(15, 2)))
	|			ELSE CAST(PricesRecipientSliceLast.Price * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentTable.Quantity * CurrencyPriceExchangeRateRecipient.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRateRecipient.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DocumentTable.Quantity * CurrencyPriceExchangeRateRecipient.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRateRecipient.Repetition)) / ISNULL(PricesRecipientSliceLast.MeasurementUnit.Factor, 1)
	|					END AS NUMBER(15, 2))
	|		END AS Amount,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN -(CAST(PricesSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2)))
	|			ELSE CAST(PricesRecipientSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))
	|		END AS AmountCur,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN -(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN CurrencyPriceExchangeRate.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRate.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN 1 / (CurrencyPriceExchangeRate.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRate.Repetition))
	|						END / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2)))
	|			ELSE CAST(PricesRecipientSliceLast.Price * DocumentTable.Quantity * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN CurrencyPriceExchangeRateRecipient.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRateRecipient.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (CurrencyPriceExchangeRateRecipient.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRateRecipient.Repetition))
	|					END / ISNULL(PricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))
	|		END AS SumForBalance,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN -(CAST(PricesSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2)))
	|			ELSE CAST(PricesRecipientSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))
	|		END AS AmountCurForBalance,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN -DocumentTable.Cost
	|			ELSE 0
	|		END AS Cost,
	|		CASE
	|			WHEN DocumentTable.ReturnFromRetailEarningAccounting
	|				THEN &ReturnAndRetail
	|			ELSE &RetailTransfer
	|		END AS ContentOfAccountingRecord
	|	FROM
	|		TemporaryTableInventory AS DocumentTable
	|			LEFT JOIN InformationRegister.Prices.SliceLast(
	|					&PointInTime,
	|					(PriceKind, Products, Characteristic) IN
	|						(SELECT
	|							TemporaryTableInventory.RetailPriceKindRecipient,
	|							TemporaryTableInventory.Products,
	|							TemporaryTableInventory.Characteristic
	|						FROM
	|							TemporaryTableInventory)) AS PricesRecipientSliceLast
	|			ON DocumentTable.Products = PricesRecipientSliceLast.Products
	|				AND DocumentTable.RetailPriceKindRecipient = PricesRecipientSliceLast.PriceKind
	|				AND DocumentTable.Characteristic = PricesRecipientSliceLast.Characteristic
	|			LEFT JOIN InformationRegister.Prices.SliceLast(
	|					&PointInTime,
	|					(PriceKind, Products, Characteristic) IN
	|						(SELECT
	|							TemporaryTableInventory.RetailPriceKind,
	|							TemporaryTableInventory.Products,
	|							TemporaryTableInventory.Characteristic
	|						FROM
	|							TemporaryTableInventory)) AS PricesSliceLast
	|			ON DocumentTable.Products = PricesSliceLast.Products
	|				AND DocumentTable.RetailPriceKind = PricesSliceLast.PriceKind
	|				AND DocumentTable.Characteristic = PricesSliceLast.Characteristic
	|			LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|					&PointInTime,
	|					Currency = &PresentationCurrency) AS ManagExchangeRate
	|			ON DocumentTable.Company = ManagExchangeRate.Company
	|			LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRateRecipient
	|			ON DocumentTable.CurrencyPricesRecipient = CurrencyPriceExchangeRateRecipient.Currency
	|				AND DocumentTable.Company = CurrencyPriceExchangeRateRecipient.Company
	|			LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRate
	|			ON DocumentTable.PriceCurrency = CurrencyPriceExchangeRate.Currency
	|				AND DocumentTable.Company = CurrencyPriceExchangeRate.Company
	|	WHERE
	|		(DocumentTable.RetailTransferEarningAccounting
	|				OR DocumentTable.ReturnFromRetailEarningAccounting)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentTable.Period,
	|		VALUE(AccumulationRecordType.Expense),
	|		DocumentTable.LineNumber,
	|		DocumentTable.Company,
	|		DocumentTable.PresentationCurrency,
	|		DocumentTable.RetailPriceKind,
	|		DocumentTable.Products,
	|		DocumentTable.Characteristic,
	|		DocumentTable.StructuralUnit,
	|		DocumentTable.PriceCurrency,
	|		DocumentTable.GLAccount,
	|		DocumentTable.SalesOrder,
	|		SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyPriceExchangeRate.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRate.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyPriceExchangeRate.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRate.Repetition))
	|				END / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		-SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyPriceExchangeRate.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRate.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyPriceExchangeRate.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRate.Repetition))
	|				END / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		-SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		DocumentTable.Cost,
	|		&RetailTransfer
	|	FROM
	|		TemporaryTableInventory AS DocumentTable
	|			LEFT JOIN InformationRegister.Prices.SliceLast(
	|					&PointInTime,
	|					(PriceKind, Products, Characteristic) IN
	|						(SELECT
	|							TemporaryTableInventory.RetailPriceKind,
	|							TemporaryTableInventory.Products,
	|							TemporaryTableInventory.Characteristic
	|						FROM
	|							TemporaryTableInventory)) AS PricesSliceLast
	|			ON DocumentTable.Products = PricesSliceLast.Products
	|				AND DocumentTable.RetailPriceKind = PricesSliceLast.PriceKind
	|				AND DocumentTable.Characteristic = PricesSliceLast.Characteristic
	|			LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|					&PointInTime,
	|					Currency = &PresentationCurrency) AS ManagExchangeRate
	|			ON DocumentTable.Company = ManagExchangeRate.Company
	|			LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRate
	|			ON DocumentTable.PriceCurrency = CurrencyPriceExchangeRate.Currency
	|				AND DocumentTable.Company = CurrencyPriceExchangeRate.Company
	|	WHERE
	|		DocumentTable.TransferInRetailEarningAccounting
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.LineNumber,
	|		DocumentTable.Company,
	|		DocumentTable.RetailPriceKind,
	|		DocumentTable.Products,
	|		DocumentTable.Characteristic,
	|		DocumentTable.StructuralUnit,
	|		DocumentTable.PriceCurrency,
	|		DocumentTable.GLAccount,
	|		DocumentTable.SalesOrder,
	|		DocumentTable.Cost,
	|		DocumentTable.PresentationCurrency
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentTable.Period,
	|		VALUE(AccumulationRecordType.Receipt),
	|		DocumentTable.LineNumber,
	|		DocumentTable.Company,
	|		DocumentTable.PresentationCurrency,
	|		DocumentTable.RetailPriceKindRecipient,
	|		DocumentTable.Products,
	|		DocumentTable.Characteristic,
	|		DocumentTable.StructuralUnitCorr,
	|		DocumentTable.CurrencyPricesRecipient,
	|		DocumentTable.FinancialAccountInRetailRecipient,
	|		DocumentTable.SalesOrder,
	|		SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyPriceExchangeRate.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRate.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyPriceExchangeRate.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRate.Repetition))
	|				END / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyPriceExchangeRate.Rate * CurrencyPriceExchangeRateRecipient.Repetition / (CurrencyPriceExchangeRateRecipient.Rate * CurrencyPriceExchangeRate.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyPriceExchangeRate.Rate * CurrencyPriceExchangeRateRecipient.Repetition / (CurrencyPriceExchangeRateRecipient.Rate * CurrencyPriceExchangeRate.Repetition))
	|				END / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyPriceExchangeRate.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRate.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyPriceExchangeRate.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRate.Repetition))
	|				END / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyPriceExchangeRate.Rate * CurrencyPriceExchangeRateRecipient.Repetition / (CurrencyPriceExchangeRateRecipient.Rate * CurrencyPriceExchangeRate.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyPriceExchangeRate.Rate * CurrencyPriceExchangeRateRecipient.Repetition / (CurrencyPriceExchangeRateRecipient.Rate * CurrencyPriceExchangeRate.Repetition))
	|				END / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|		DocumentTable.Cost,
	|		&RetailTransfer
	|	FROM
	|		TemporaryTableInventory AS DocumentTable
	|			LEFT JOIN InformationRegister.Prices.SliceLast(
	|					&PointInTime,
	|					(PriceKind, Products, Characteristic) IN
	|						(SELECT
	|							TemporaryTableInventory.RetailPriceKind,
	|							TemporaryTableInventory.Products,
	|							TemporaryTableInventory.Characteristic
	|						FROM
	|							TemporaryTableInventory)) AS PricesSliceLast
	|			ON DocumentTable.Products = PricesSliceLast.Products
	|				AND DocumentTable.RetailPriceKind = PricesSliceLast.PriceKind
	|				AND DocumentTable.Characteristic = PricesSliceLast.Characteristic
	|			LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|					&PointInTime,
	|					Currency = &PresentationCurrency) AS ManagExchangeRate
	|			ON DocumentTable.Company = ManagExchangeRate.Company
	|			LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRate
	|			ON DocumentTable.PriceCurrency = CurrencyPriceExchangeRate.Currency
	|				AND DocumentTable.Company = CurrencyPriceExchangeRate.Company
	|			LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRateRecipient
	|			ON DocumentTable.CurrencyPricesRecipient = CurrencyPriceExchangeRateRecipient.Currency
	|				AND DocumentTable.Company = CurrencyPriceExchangeRateRecipient.Company
	|	WHERE
	|		DocumentTable.TransferInRetailEarningAccounting
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.LineNumber,
	|		DocumentTable.Company,
	|		DocumentTable.RetailPriceKindRecipient,
	|		DocumentTable.Products,
	|		DocumentTable.Characteristic,
	|		DocumentTable.StructuralUnitCorr,
	|		DocumentTable.CurrencyPricesRecipient,
	|		DocumentTable.FinancialAccountInRetailRecipient,
	|		DocumentTable.SalesOrder,
	|		DocumentTable.Cost,
	|		DocumentTable.PresentationCurrency) AS DocumentTable
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	Currency,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTablePOSSummary.Company AS Company,
	|	TemporaryTablePOSSummary.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTablePOSSummary.StructuralUnit AS StructuralUnit,
	|	TemporaryTablePOSSummary.Currency AS Currency
	|FROM
	|	TemporaryTablePOSSummary AS TemporaryTablePOSSummary";
	
	QueryResult = Query.Execute();
	
	Block 				= New DataLock;
	LockItem 			= Block.Add("AccumulationRegister.POSSummary");
	LockItem.Mode 		= DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesPOSSummary(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePOSSummary", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefInventoryTransfer, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("MoveToRIMContent",				NStr("en = 'Retail markup'; ru = 'Торговая наценка';pl = 'Marża detaliczna';es_ES = 'Marca de la venta al por menor';es_CO = 'Marca de la venta al por menor';tr = 'Perakende kâr marjı';it = 'Margine di vendita al dettaglio';de = 'Einzelhandels-Aufschlag'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("Ref",							DocumentRefInventoryTransfer);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	Query.SetParameter("FillAmount", FillAmount);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS AccountDr,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	0 AS AmountCurDr,
	|	0 AS AmountCurCr,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS Amount,
	|	&ExchangeDifference AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.FinancialAccountInRetailRecipient,
	|	DocumentTable.MarkupGLAccountRecipient,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(CAST(PricesRecipientSliceLast.Price * DocumentTable.Quantity * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyPriceExchangeRateRecipient.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRateRecipient.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyPriceExchangeRateRecipient.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRateRecipient.Repetition))
	|				END / ISNULL(PricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|	&MoveToRIMContent,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&PointInTime,
	|				(PriceKind, Products, Characteristic) IN
	|					(SELECT
	|						TemporaryTableInventory.RetailPriceKindRecipient,
	|						TemporaryTableInventory.Products,
	|						TemporaryTableInventory.Characteristic
	|					FROM
	|						TemporaryTableInventory)) AS PricesRecipientSliceLast
	|		ON DocumentTable.Products = PricesRecipientSliceLast.Products
	|			AND DocumentTable.RetailPriceKindRecipient = PricesRecipientSliceLast.PriceKind
	|			AND DocumentTable.Characteristic = PricesRecipientSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency) AS ManagExchangeRate
	|		ON DocumentTable.Company = ManagExchangeRate.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRateRecipient
	|		ON DocumentTable.CurrencyPricesRecipient = CurrencyPriceExchangeRateRecipient.Currency
	|			AND DocumentTable.Company = CurrencyPriceExchangeRateRecipient.Company
	|WHERE
	|	DocumentTable.RetailTransferEarningAccounting
	|	AND NOT &FillAmount
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.FinancialAccountInRetailRecipient,
	|	DocumentTable.MarkupGLAccountRecipient
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.MarkupGLAccount,
	|	DocumentTable.GLAccount,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(CAST(PricesRecipientSliceLast.Price * DocumentTable.Quantity * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN CurrencyPriceExchangeRate.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRate.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (CurrencyPriceExchangeRate.Rate * ManagExchangeRate.Repetition / (ManagExchangeRate.Rate * CurrencyPriceExchangeRate.Repetition))
	|				END / ISNULL(PricesRecipientSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))),
	|	&MoveToRIMContent,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&PointInTime,
	|				(PriceKind, Products, Characteristic) IN
	|					(SELECT
	|						TemporaryTableInventory.RetailPriceKind,
	|						TemporaryTableInventory.Products,
	|						TemporaryTableInventory.Characteristic
	|					FROM
	|						TemporaryTableInventory)) AS PricesRecipientSliceLast
	|		ON DocumentTable.Products = PricesRecipientSliceLast.Products
	|			AND DocumentTable.RetailPriceKind = PricesRecipientSliceLast.PriceKind
	|			AND DocumentTable.Characteristic = PricesRecipientSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency = &PresentationCurrency) AS ManagExchangeRate
	|		ON DocumentTable.Company = ManagExchangeRate.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS CurrencyPriceExchangeRate
	|		ON DocumentTable.PriceCurrency = CurrencyPriceExchangeRate.Currency
	|			AND DocumentTable.Company = CurrencyPriceExchangeRate.Company
	|WHERE
	|	DocumentTable.ReturnFromRetailEarningAccounting
	|	AND NOT &FillAmount
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.MarkupGLAccount,
	|	DocumentTable.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Amount,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the SerialNumbersInWarranty information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count()=0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableInventory.Cell AS Cell,
	|	TemporaryTableInventory.OperationKind AS OperationKind,
	|	TemporaryTableInventory.Ownership AS Ownership,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey
	|WHERE
	|	TemporaryTableInventory.SerialNumber = FALSE
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableInventory.Period,
	|	VALUE(AccumulationRecordType.Receipt),
	|	SerialNumbers.SerialNumber,
	|	TemporaryTableInventory.Products,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.BatchCorr,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.StructuralUnitCorr,
	|	TemporaryTableInventory.CorrCell,
	|	TemporaryTableInventory.OperationKind,
	|	TemporaryTableInventory.Ownership,
	|	1
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey
	|WHERE
	|	NOT TemporaryTableInventory.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|	AND TemporaryTableInventory.SerialNumber = FALSE
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableInventory.Period,
	|	VALUE(AccumulationRecordType.Expense),
	|	TemporaryTableInventory.SerialNumber,
	|	TemporaryTableInventory.Products,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Batch,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.StructuralUnit,
	|	TemporaryTableInventory.Cell,
	|	TemporaryTableInventory.OperationKind,
	|	TemporaryTableInventory.Ownership,
	|	1
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|WHERE
	|	NOT TemporaryTableInventory.SerialNumber = FALSE
	|	AND NOT TemporaryTableInventory.SerialNumber = VALUE(Catalog.SerialNumbers.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableInventory.Period,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTableInventory.SerialNumber,
	|	TemporaryTableInventory.Products,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.BatchCorr,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.StructuralUnitCorr,
	|	TemporaryTableInventory.CorrCell,
	|	TemporaryTableInventory.OperationKind,
	|	TemporaryTableInventory.Ownership,
	|	1
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|WHERE
	|	NOT TemporaryTableInventory.SerialNumber = FALSE
	|	AND NOT TemporaryTableInventory.SerialNumber = VALUE(Catalog.SerialNumbers.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TemporaryTableInventory.Period AS EventDate,
	|	CASE
	|		WHEN TemporaryTableInventory.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|			THEN VALUE(Enum.SerialNumbersOperations.Expense)
	|		ELSE VALUE(Enum.SerialNumbersOperations.Record)
	|	END AS Operation,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey
	|WHERE
	|	TemporaryTableInventory.SerialNumber = FALSE
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	TemporaryTableInventory.Period,
	|	CASE
	|		WHEN TemporaryTableInventory.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.WriteOffToExpenses)
	|			THEN VALUE(Enum.SerialNumbersOperations.Expense)
	|		ELSE VALUE(Enum.SerialNumbersOperations.Record)
	|	END,
	|	TemporaryTableInventory.SerialNumber,
	|	TemporaryTableInventory.Products,
	|	TemporaryTableInventory.Characteristic
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|WHERE
	|	NOT TemporaryTableInventory.SerialNumber = FALSE
	|	AND NOT TemporaryTableInventory.SerialNumber = VALUE(Catalog.SerialNumbers.EmptyRef)";
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", ResultsArray[1].Unload());
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", ResultsArray[0].Unload());
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf;
	
EndProcedure

// Function returns query text by the balance of TransferOrders register.
//
Function GenerateQueryTextBalancesTransferOrders()
	
	QueryText =
	"SELECT
	|	RegisterRecordsTransferOrdersChange.LineNumber AS LineNumber,
	|	RegisterRecordsTransferOrdersChange.Company AS CompanyPresentation,
	|	RegisterRecordsTransferOrdersChange.TransferOrder AS OrderPresentation,
	|	RegisterRecordsTransferOrdersChange.Products AS ProductsPresentation,
	|	RegisterRecordsTransferOrdersChange.Characteristic AS CharacteristicPresentation,
	|	TransferOrdersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsTransferOrdersChange.QuantityChange, 0) + ISNULL(TransferOrdersBalances.QuantityBalance, 0) AS BalanceTransferOrders,
	|	ISNULL(TransferOrdersBalances.QuantityBalance, 0) AS QuantityBalanceTransferOrders
	|FROM
	|	RegisterRecordsTransferOrdersChange AS RegisterRecordsTransferOrdersChange
	|		INNER JOIN AccumulationRegister.TransferOrders.Balance(&ControlTime, ) AS TransferOrdersBalances
	|		ON RegisterRecordsTransferOrdersChange.Company = TransferOrdersBalances.Company
	|			AND RegisterRecordsTransferOrdersChange.TransferOrder = TransferOrdersBalances.TransferOrder
	|			AND RegisterRecordsTransferOrdersChange.Products = TransferOrdersBalances.Products
	|			AND RegisterRecordsTransferOrdersChange.Characteristic = TransferOrdersBalances.Characteristic
	|			AND (ISNULL(TransferOrdersBalances.QuantityBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + DriveClientServer.GetQueryDelimeter();
	
EndFunction

Function GetFillReserveColumnQueryText()
	
	Return DriveClientServer.GetQueryDelimeter() +
	"SELECT ALLOWED
	|	ReservedProductsBalances.Products AS Products,
	|	ReservedProductsBalances.Characteristic AS Characteristic,
	|	ReservedProductsBalances.Batch AS Batch,
	|	ReservedProductsBalances.SalesOrder AS Order,
	|	SUM(ReservedProductsBalances.QuantityBalance) AS QuantityBalance
	|INTO TT_ReservedProductsBalances
	|FROM
	|	(SELECT
	|		ReservedProductsBalances.SalesOrder AS SalesOrder,
	|		ReservedProductsBalances.Products AS Products,
	|		ReservedProductsBalances.Characteristic AS Characteristic,
	|		ReservedProductsBalances.Batch AS Batch,
	|		ReservedProductsBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				,
	|				Company = &Company
	|					AND StructuralUnit = &StructuralUnit
	|					AND SalesOrder <> UNDEFINED
	|					AND (Products, Characteristic, Batch, SalesOrder) IN
	|						(SELECT
	|							TT_InventoryToFillReserve.Products,
	|							TT_InventoryToFillReserve.Characteristic,
	|							TT_InventoryToFillReserve.Batch,
	|							TT_InventoryToFillReserve.SalesOrder
	|						FROM
	|							TT_InventoryToFillReserve AS TT_InventoryToFillReserve)) AS ReservedProductsBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsReservedProducts.SalesOrder,
	|		DocumentRegisterRecordsReservedProducts.Products,
	|		DocumentRegisterRecordsReservedProducts.Characteristic,
	|		DocumentRegisterRecordsReservedProducts.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsReservedProducts.Quantity
	|			ELSE -DocumentRegisterRecordsReservedProducts.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.SalesOrder <> UNDEFINED) AS ReservedProductsBalances
	|
	|GROUP BY
	|	ReservedProductsBalances.SalesOrder,
	|	ReservedProductsBalances.Products,
	|	ReservedProductsBalances.Characteristic,
	|	ReservedProductsBalances.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryToFillReserve.LineNumber AS LineNumber,
	|	TT_InventoryToFillReserve.Products AS Products,
	|	TT_InventoryToFillReserve.Characteristic AS Characteristic,
	|	TT_InventoryToFillReserve.Batch AS Batch,
	|	TT_InventoryToFillReserve.SalesOrder AS SalesOrder,
	|	TT_InventoryToFillReserve.Factor AS Factor,
	|	TT_InventoryToFillReserve.Quantity * TT_InventoryToFillReserve.Factor AS BaseQuantity,
	|	SUM(TT_InventoryToFillReserveCumulative.Quantity * TT_InventoryToFillReserveCumulative.Factor) AS BaseQuantityCumulative
	|INTO TT_InventoryToFillReserveCumulative
	|FROM
	|	TT_InventoryToFillReserve AS TT_InventoryToFillReserve
	|		INNER JOIN TT_InventoryToFillReserve AS TT_InventoryToFillReserveCumulative
	|		ON TT_InventoryToFillReserve.Products = TT_InventoryToFillReserveCumulative.Products
	|			AND TT_InventoryToFillReserve.Characteristic = TT_InventoryToFillReserveCumulative.Characteristic
	|			AND TT_InventoryToFillReserve.Batch = TT_InventoryToFillReserveCumulative.Batch
	|			AND TT_InventoryToFillReserve.SalesOrder = TT_InventoryToFillReserveCumulative.SalesOrder
	|			AND TT_InventoryToFillReserve.LineNumber >= TT_InventoryToFillReserveCumulative.LineNumber
	|
	|GROUP BY
	|	TT_InventoryToFillReserve.LineNumber,
	|	TT_InventoryToFillReserve.Characteristic,
	|	TT_InventoryToFillReserve.Batch,
	|	TT_InventoryToFillReserve.SalesOrder,
	|	TT_InventoryToFillReserve.Products,
	|	TT_InventoryToFillReserve.Factor,
	|	TT_InventoryToFillReserve.Quantity * TT_InventoryToFillReserve.Factor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryToFillReserveCumulative.LineNumber AS LineNumber,
	|	TT_InventoryToFillReserveCumulative.SalesOrder AS SalesOrder,
	|	TT_InventoryToFillReserveCumulative.Factor AS Factor,
	|	TT_InventoryToFillReserveCumulative.BaseQuantity AS BaseQuantity,
	|	CASE
	|		WHEN TT_ReservedProductsBalances.QuantityBalance > TT_InventoryToFillReserveCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryToFillReserveCumulative.BaseQuantity
	|		WHEN TT_ReservedProductsBalances.QuantityBalance > TT_InventoryToFillReserveCumulative.BaseQuantityCumulative - TT_InventoryToFillReserveCumulative.BaseQuantity
	|			THEN TT_ReservedProductsBalances.QuantityBalance - (TT_InventoryToFillReserveCumulative.BaseQuantityCumulative - TT_InventoryToFillReserveCumulative.BaseQuantity)
	|		ELSE 0
	|	END AS BaseReserve
	|INTO TT_InventoryReserve
	|FROM
	|	TT_InventoryToFillReserveCumulative AS TT_InventoryToFillReserveCumulative
	|		LEFT JOIN TT_ReservedProductsBalances AS TT_ReservedProductsBalances
	|		ON TT_InventoryToFillReserveCumulative.Products = TT_ReservedProductsBalances.Products
	|			AND TT_InventoryToFillReserveCumulative.Characteristic = TT_ReservedProductsBalances.Characteristic
	|			AND TT_InventoryToFillReserveCumulative.Batch = TT_ReservedProductsBalances.Batch
	|			AND TT_InventoryToFillReserveCumulative.SalesOrder = TT_ReservedProductsBalances.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Products.LineNumber AS LineNumber,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Batch AS Batch,
	|	TT_Products.Quantity AS Quantity,
	|	CASE
	|		WHEN TT_InventoryReserve.BaseReserve = TT_InventoryReserve.BaseQuantity
	|			THEN TT_Products.Quantity
	|		ELSE TT_InventoryReserve.BaseReserve / TT_InventoryReserve.Factor
	|	END AS Reserve,
	|	TT_Products.MeasurementUnit AS MeasurementUnit,
	|	TT_Products.Factor AS Factor,
	|	TT_Products.SalesOrder AS SalesOrder,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssues
	|FROM
	|	TT_InventoryToFillReserve AS TT_Products
	|		LEFT JOIN TT_InventoryReserve AS TT_InventoryReserve
	|		ON TT_Products.LineNumber = TT_InventoryReserve.LineNumber
	|			AND TT_Products.SalesOrder = TT_InventoryReserve.SalesOrder
	|";

EndFunction

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);
EndProcedure

#EndRegion

#EndIf