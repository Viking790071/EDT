#Region Public

Procedure FillReservationTable(DocObject, WriteMode, Cancel) Export
	
	If WriteMode <> DocumentWriteMode.Posting Then
		Return;
	EndIf;
	
	DocObject.Reservation.Clear();
	
	ParametersSet = DocumentParameters(DocObject, True);
	
	For Each Parameters In ParametersSet Do
		
		AddKeyFields(Parameters, DocObject);
		
		Parameters.Insert("UseBalance", True);
		Parameters.Insert("TempTablesManager", New TempTablesManager);
		
		If Not DocObject.Posted
			Or HeaderAttributesChanged(Parameters, DocObject) Then
			DocObject[Parameters.ReservationTableName].Clear();
		EndIf;
		
		GetDocumentTables(Parameters, DocObject);
		
		GetBalancesTable(Parameters, DocObject);
		
		FillReservation(Parameters);
		
		AllocateAmounts(Parameters);
		
		// begin Drive.FullVersion
		
		If TypeOf(DocObject) = Type("DocumentObject.Manufacturing")
			And TypeOf(DocObject.SalesOrder) = Type("DocumentRef.SubcontractorOrderReceived") Then
			Parameters.Table_AlreadyFilled.FillValues(DocObject.SalesOrder, "SalesOrder");
		EndIf;
		
		// end Drive.FullVersion
		
		CheckSalesOrderDates(Parameters.Table_AlreadyFilled);
		
		DocObject[Parameters.ReservationTableName].Load(Parameters.Table_AlreadyFilled);
		
	EndDo;
	
EndProcedure

Function CheckReservedProductsChange(ParametersData) Export
	
	Query = New Query;
	Query.SetParameter("ProductsChanges", ParametersData.ProductsChanges);
	Query.SetParameter("Ref", ParametersData.Ref);
	
	MetaDocument = ParametersData.Ref.Metadata();
	Query.Text =
	"SELECT
	|	ReservedProductsChanges.Products AS Products,
	|	ReservedProductsChanges.Characteristic AS Characteristic,
	|	ReservedProductsChanges.Batch AS Batch,
	|	ReservedProductsChanges.Order AS Order,
	|	ReservedProductsChanges.SerialNumbers AS SerialNumbers,
	|	ReservedProductsChanges.MeasurementUnit AS MeasurementUnit,
	|	ReservedProductsChanges.Quantity AS Quantity
	|INTO ReservedProductsChangesRre
	|FROM
	|	&ProductsChanges AS ReservedProductsChanges
	|;
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReservedProductsChangesRre.Products AS Products,
	|	ReservedProductsChangesRre.Characteristic AS Characteristic,
	|	ReservedProductsChangesRre.Batch AS Batch,
	|	ReservedProductsChangesRre.Order AS Order,
	|	ReservedProductsChangesRre.MeasurementUnit AS MeasurementUnit,
	|	ReservedProductsChangesRre.SerialNumbers AS SerialNumbers,
	|	SUM(ReservedProductsChangesRre.Quantity) AS Quantity
	|INTO ReservedProductsChanges
	|FROM
	|	ReservedProductsChangesRre AS ReservedProductsChangesRre
	|GROUP BY
	|	ReservedProductsChangesRre.Products,
	|	ReservedProductsChangesRre.Batch,
	|	ReservedProductsChangesRre.Order,
	|	ReservedProductsChangesRre.Characteristic,
	|	ReservedProductsChangesRre.MeasurementUnit,
	|	ReservedProductsChangesRre.SerialNumbers
	|;
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SupplierInvoiceReservation.Products AS Products,
	|	SupplierInvoiceReservation.Characteristic AS Characteristic,
	|	SupplierInvoiceReservation.Batch AS Batch,
	|	SupplierInvoiceReservation.Order AS Order,
	|	SupplierInvoiceReservation.MeasurementUnit AS MeasurementUnit,
	|	SupplierInvoiceReservation.SerialNumbers AS SerialNumbers,
	|	SUM(SupplierInvoiceReservation.Quantity) AS Quantity
	|INTO ReservedProducts
	|FROM
	|	Document."+MetaDocument.Name+"."+ ParametersData.TableName +" AS SupplierInvoiceReservation
	|WHERE
	|	SupplierInvoiceReservation.Ref = &Ref
	|
	|GROUP BY
	|	SupplierInvoiceReservation.Products,
	|	SupplierInvoiceReservation.Batch,
	|	SupplierInvoiceReservation.Order,
	|	SupplierInvoiceReservation.Characteristic,
	|	SupplierInvoiceReservation.MeasurementUnit,
	|	SupplierInvoiceReservation.SerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	ReservedProducts.Products AS Products
	|FROM
	|	ReservedProductsChanges AS ReservedProductsChanges
	|		FULL JOIN ReservedProducts AS ReservedProducts
	|		ON ReservedProductsChanges.Products = ReservedProducts.Products
	|			AND ReservedProductsChanges.Characteristic = ReservedProducts.Characteristic
	|			AND ReservedProductsChanges.Batch = ReservedProducts.Batch
	|			AND ReservedProductsChanges.Order = ReservedProducts.Order
	|			AND ReservedProductsChanges.SerialNumbers = ReservedProducts.SerialNumbers
	|			AND ReservedProductsChanges.MeasurementUnit = ReservedProducts.MeasurementUnit
	|			AND ReservedProductsChanges.Quantity = ReservedProducts.Quantity
	|WHERE
	|	(ReservedProducts.Products IS NULL
	|			OR ReservedProductsChanges.Characteristic IS NULL
	|			OR ReservedProductsChanges.Batch IS NULL
	|			OR ReservedProductsChanges.Order IS NULL
	|			OR ReservedProductsChanges.MeasurementUnit IS NULL
	|			OR ReservedProductsChanges.SerialNumbers IS NULL
	|			OR ReservedProductsChanges.Quantity IS NULL
	|			OR ReservedProducts.Products IS NULL
	|			OR ReservedProducts.Characteristic IS NULL
	|			OR ReservedProducts.Batch IS NULL
	|			OR ReservedProducts.Order IS NULL
	|			OR ReservedProducts.MeasurementUnit IS NULL
	|			OR ReservedProducts.SerialNumbers IS NULL
	|			OR ReservedProducts.Quantity IS NULL)";
	
	If Not ParametersData.UseOrder Then
		
		NewQueryLines = New Array;
		
		For LineCounter = 1 To StrLineCount(Query.Text) Do
			
			CurrentLine = StrGetLine(Query.Text, LineCounter);
			
			If Not StrFind(CurrentLine, "Order") > 0 Then
				NewQueryLines.Add(CurrentLine);
			EndIf;
			
		EndDo;
		
		Query.Text = StrConcat(NewQueryLines, Chars.LF);
		
	EndIf;
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Procedure ClearReserves(DocObject) Export
	
	DocObject.AdjustedReserved = False;
	
EndProcedure

Function GetDataFormInventoryReservationForm(DocObject) Export
	
	Data = New Structure;
	
	ParametersSet = DocumentParameters(DocObject, True);
	
	Parameters = ParametersSet[0];
	
	AddKeyFields(Parameters, DocObject);
	
	Parameters.Insert("UseBalance", True);
	Parameters.Insert("TempTablesManager", New TempTablesManager);
	
	Data.Insert("Parameters", Parameters);
	
	DocObjectStructure = New Structure;
	DocObjectStructure.Insert("Ref", DocObject.Ref);
	
	Inventory = DocObject[Parameters.TableName].Unload();
	InventoryReservation = DocObject[Parameters.ReservationTableName].Unload();
	
	// begin Drive.FullVersion

	If TypeOf(DocObject) = Type("DocumentObject.Manufacturing")
		Or TypeOf(DocObject) = Type("DocumentObject.Production") Then
		
		Inventory.Columns.Add("Order");
		Inventory.FillValues(DocObject.BasisDocument, "Order");
		
		InventoryReservation.Columns.Add("Order");
		InventoryReservation.FillValues(DocObject.BasisDocument, "Order");
		
	EndIf;
	
	// end Drive.FullVersion
	
	DocObjectStructure.Insert("Inventory", Inventory);
	DocObjectStructure.Insert("InventoryReservation", InventoryReservation);
	DocObjectStructure.Insert("BasisDocument", ?(TypeOf(DocObject) = Type("DocumentObject.GoodsReceipt"), Undefined,
		DocObject.BasisDocument));
	
	Data.Insert("DocObject", DocObjectStructure);
	
	Data.Insert("KeyTable", GetTableForReservationTreeFilling(Parameters, DocObjectStructure));
	
	GetBalancesTable(Parameters, DocObject, True);
	
	Parameters.TempTablesManager = Undefined;
	
	Return Data;
	
EndFunction

#EndRegion

#Region Private

Function HeaderAttributesChanged(Parameters, DocObject)
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	TRUE AS HeaderAttributesChanged
	|FROM
	|	&DocumentTable AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND (DocumentTable.Date <> &Date
	|				AND NOT &IgnoreDateChange
	|			OR DocumentTable._HeaderFieldsValue <> &_HeaderFields
	|)";
	
	Query.SetParameter("Ref", DocObject.Ref);
	Query.SetParameter("Date", DocObject.Date);
	IgnoreDateChange = False;
	
	Query.SetParameter("IgnoreDateChange", IgnoreDateChange);
	Query.Text = StrReplace(Query.Text, "&DocumentTable", Parameters.DocMetadata.FullName());
	ReplaceWithRealFieldNames(Query, Parameters);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Procedure FillReservation(Parameters)
	
	SearchFilter = New Structure(
		"Company,
		|Products,
		|Characteristic,
		|Order");
	
	EmptyOrder = Documents.SalesOrder.EmptyRef();
	
	For Each ToBeFilledRow In Parameters.Table_ToBeFilled Do
		
		FillPropertyValues(SearchFilter, ToBeFilledRow);
		BalancesRows = Parameters.Table_Balances.FindRows(SearchFilter);
		
		QuantityNeeded = ToBeFilledRow.Quantity;
		
		For Each BalancesRow In BalancesRows Do
			
			If BalancesRow.Quantity <=0 Then
				Continue;
			EndIf;
			
			NewRow = Parameters.Table_AlreadyFilled.Add();
			FillPropertyValues(NewRow, ToBeFilledRow);
			NewRow.SalesOrder = BalancesRow.SalesOrder;
			
			NewRow.Quantity = Min(QuantityNeeded, BalancesRow.Quantity);
			BalancesRow.Quantity = BalancesRow.Quantity - NewRow.Quantity;
			QuantityNeeded = QuantityNeeded - NewRow.Quantity;
			
			If QuantityNeeded <= 0 Then
				Break;
			EndIf;
			
		EndDo;
		
		If QuantityNeeded <> 0 Then
			
			NewRow = Parameters.Table_AlreadyFilled.Add();
			FillPropertyValues(NewRow, ToBeFilledRow);
			
			NewRow.SalesOrder = EmptyOrder;
			NewRow.Quantity = QuantityNeeded;
			
		EndIf;
		
	EndDo;
	
	GroupingColumns = StringFunctionsClientServer.StringFromSubstringArray(Parameters.KeyFields);
	GroupingColumns = GroupingColumns + ", Order, SalesOrder";
	
	TotalingColumns = StringFunctionsClientServer.StringFromSubstringArray(Parameters.AmountFields);
	TotalingColumns = TotalingColumns + ", Quantity";
	
	Parameters.Table_AlreadyFilled.GroupBy(GroupingColumns, TotalingColumns);
	
EndProcedure

Function DocumentParameters(DocObject, DoesntUseBatch = False)
	
	DocManager = Common.ObjectManagerByRef(DocObject.Ref);
	
	IncomingParameters = InventoryReservationParameters(DocObject);
	
	If TypeOf(IncomingParameters) = Type("Array") Then
		ParametersSet = IncomingParameters;
	Else
		ParametersSet = New Array;
		ParametersSet.Add(IncomingParameters);
	EndIf;
	
	DocMetadata = DocObject.Metadata();
	
	TableName = "Products";
	
	If TypeOf(DocObject) = Type("DocumentObject.SupplierInvoice") Then
		TableName = "Inventory";
		
	// begin Drive.FullVersion
	
	ElsIf TypeOf(DocObject) = Type("DocumentObject.Manufacturing")
		And DocObject.OperationKind = Enums.OperationTypesProduction.Disassembly Then
		TableName = "Inventory";
	ElsIf TypeOf(DocObject) = Type("DocumentObject.Production")
		And DocObject.OperationKind = Enums.OperationTypesProduction.Disassembly Then
		TableName = "Inventory";
		
	// end Drive.FullVersion
	
	ElsIf TypeOf(DocObject) = Type("DocumentObject.GoodsReceipt") Then
		TableName = "Products"
	EndIf;
	
	For Each Parameters In ParametersSet Do 
		
		Parameters.Insert("DocMetadata", DocMetadata);
		
		If Not Parameters.Property("TableName") Then
			Parameters.Insert("TableName", TableName);
		EndIf;
		If Not Parameters.Property("ReservationTableName") Then
			Parameters.Insert("ReservationTableName", "Reservation");
		EndIf;
		If Not Parameters.Property("FieldsToSkip") Then
			Parameters.Insert("FieldsToSkip", GetFieldsToSkip(Parameters, DoesntUseBatch));
		EndIf;
		
	EndDo;
	
	Return ParametersSet;
	
EndFunction

Procedure AddKeyFields(Parameters, DocObject)
	
	DocMetaTabularSections = Parameters.DocMetadata.TabularSections;
	
	KeyFields = New Array;
	
	For Each Attribute In DocMetaTabularSections[Parameters.ReservationTableName].Attributes Do
		
		AttributeName = Attribute.Name;
		
		If Parameters.AmountFields.Find(AttributeName) = Undefined
			And Parameters.FieldsToSkip.Find(AttributeName) = Undefined Then
			
			KeyFields.Add(AttributeName);
		EndIf;
		
	EndDo;
	
	Parameters.Insert("KeyFields", KeyFields);
	
EndProcedure

Function InventoryReservationParameters(DocObject)
	
	Parameters = New Structure;
	
	AmountFields = New Array;
	
	If TypeOf(DocObject) = Type("DocumentObject.SupplierInvoice")
		
		// begin Drive.FullVersion
		
		Or TypeOf(DocObject) = Type("DocumentObject.Manufacturing")
		
		// end Drive.FullVersion
		
		Or TypeOf(DocObject) = Type("DocumentObject.Production")
		Or TypeOf(DocObject) = Type("DocumentObject.GoodsReceipt") Then
	Else
		AmountFields.Add("Amount");
		AmountFields.Add("VATAmount");
		AmountFields.Add("Total");
		AmountFields.Add("SalesTaxAmount");
		AmountFields.Add("Reserve");
	EndIf;
	
	Parameters.Insert("AmountFields", AmountFields);
	
	HeaderFields = New Structure;
	HeaderFields.Insert("Company", "Company");
	HeaderFields.Insert("StructuralUnit", "StructuralUnit");
	
	If TypeOf(DocObject) <> Type("DocumentObject.GoodsReceipt") Then
		HeaderFields.Insert("OperationKind", "OperationKind");
	EndIf;
	
	Parameters.Insert("HeaderFields", HeaderFields);
	
	Parameters.Insert("UseOrder", (TypeOf(DocObject) = Type("DocumentObject.SupplierInvoice"))
		Or (TypeOf(DocObject) = Type("DocumentObject.GoodsReceipt")));
	
	Return Parameters;
	
EndFunction

Procedure GetDocumentTables(Parameters, DocObject)
	
	Query = New Query;
	Query.TempTablesManager = Parameters.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	InventoryDocTable._KeyFields AS _KeyFields,
	|	InventoryDocTable._AmountFields AS _AmountFields,
	|	_OrderFields
	|	InventoryDocTable.MeasurementUnit AS MeasurementUnit,
	|	InventoryDocTable.Quantity AS Quantity
	|INTO TT_InventoryAsIs_Initial
	|FROM
	|	&Inventory AS InventoryDocTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TRUE AS AuxiliaryGroupingField,
	|	TT_InventoryAsIs_Initial._KeyFields AS _KeyFields,
	|	SUM(TT_InventoryAsIs_Initial._AmountFields) AS _AmountFields,
	|	TT_InventoryAsIs_Initial.Order AS Order,
	|	TT_InventoryAsIs_Initial.MeasurementUnit AS MeasurementUnit,
	|	SUM(TT_InventoryAsIs_Initial.Quantity) AS Quantity
	|INTO TT_InventoryAsIs
	|FROM
	|	TT_InventoryAsIs_Initial AS TT_InventoryAsIs_Initial
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON TT_InventoryAsIs_Initial.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON (&StructuralUnit = BatchTrackingPolicy.StructuralUnit)
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|GROUP BY
	|	TT_InventoryAsIs_Initial._KeyFields,
	|	TT_InventoryAsIs_Initial.Order,
	|	TT_InventoryAsIs_Initial.MeasurementUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryDocTable._KeyFields AS _KeyFields,
	|	InventoryDocTable._AmountFields AS _AmountFields,
	|	_OrderFields
	|	InventoryDocTable.SalesOrder AS SalesOrder,
	|	InventoryDocTable.Quantity AS Quantity
	|INTO TT_ReservationAsIs
	|FROM
	|	&InventoryReservation AS InventoryDocTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryAsIs.AuxiliaryGroupingField AS AuxiliaryGroupingField,
	|	TT_InventoryAsIs._KeyFields AS _KeyFields,
	|	SUM(TT_InventoryAsIs._AmountFields) AS _AmountFields,
	|	TT_InventoryAsIs.MeasurementUnit AS MeasurementUnit,
	|	TT_InventoryAsIs.Order AS Order,
	|	SUM(TT_InventoryAsIs.Quantity * ISNULL(UOM.Factor, 1)) AS Quantity
	|INTO TT_InventoryGrouped
	|FROM
	|	TT_InventoryAsIs AS TT_InventoryAsIs
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TT_InventoryAsIs.MeasurementUnit = UOM.Ref
	|
	|GROUP BY
	|	TT_InventoryAsIs._KeyFields,
	|	TT_InventoryAsIs.AuxiliaryGroupingField,
	|	TT_InventoryAsIs.MeasurementUnit,
	|	TT_InventoryAsIs.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryGrouped._KeyFields AS _KeyFields,
	|	TT_InventoryGrouped._AmountFields AS _AmountFields,
	|	TT_InventoryGrouped.Order AS Order,
	|	SUM(TT_InventoryGrouped.Quantity) AS Quantity
	|INTO TT_Inventory
	|FROM
	|	TT_InventoryGrouped AS TT_InventoryGrouped
	|		LEFT JOIN TT_InventoryAsIs AS TT_InventoryAsIs
	|		ON TT_InventoryGrouped.Order = TT_InventoryAsIs.Order
	|			AND TT_InventoryGrouped.MeasurementUnit = TT_InventoryAsIs.MeasurementUnit
	|			AND TT_InventoryGrouped._KeyFields = TT_InventoryAsIs._KeyFields
	|GROUP BY
	|	TT_InventoryGrouped._KeyFields,
	|	TT_InventoryGrouped.Order
	|			
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ReservationAsIs._KeyFields AS _KeyFields,
	|	TT_ReservationAsIs._AmountFields AS _AmountFields,
	|	TT_ReservationAsIs.SalesOrder AS SalesOrder,
	|	TT_ReservationAsIs.Order AS Order,
	|	TT_ReservationAsIs.Quantity AS Quantity
	|INTO TT_Reservation
	|FROM
	|	TT_ReservationAsIs AS TT_ReservationAsIs
	|		INNER JOIN TT_Inventory AS TT_Inventory
	|		ON (TRUE)
	|			AND TT_ReservationAsIs.Order = TT_Inventory.Order
	|			AND TT_ReservationAsIs._KeyFields = TT_Inventory._KeyFields
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TRUE AS AuxiliaryGroupingField,
	|	TT_InventoryGrouped._KeyFields AS _KeyFields,
	|	TT_InventoryGrouped._AmountFields AS _AmountFields,
	|	TT_InventoryGrouped.Order AS Order,
	|	TT_InventoryGrouped.Quantity AS Quantity
	|INTO TT_Union
	|FROM
	|	TT_InventoryGrouped AS TT_InventoryGrouped
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE,
	|	TT_Reservation._KeyFields,
	|	-TT_Reservation._AmountFields,
	|	TT_Reservation.Order,
	|	-TT_Reservation.Quantity
	|FROM
	|	TT_Reservation AS TT_Reservation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Union._KeyFields AS _KeyFields,
	|	SUM(TT_Union._AmountFields) AS _AmountFields,
	|	TT_Union.Order,
	|	SUM(TT_Union.Quantity) AS Quantity
	|INTO TT_UnionGrouped
	|FROM
	|	TT_Union AS TT_Union
	|GROUP BY
	|	TT_Union._KeyFields,
	|	TT_Union.Order,
	|	TT_Union.AuxiliaryGroupingField
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&_HeaderFields AS _HeaderFields,
	|	TT_Reservation._KeyFields AS _KeyFields,
	|	TT_Reservation._AmountFields AS _AmountFields,
	|	TT_Reservation.Order AS Order,
	|	TT_Reservation.SalesOrder AS SalesOrder,
	|	TT_Reservation.Quantity AS Quantity
	|INTO TT_AlreadyFilled
	|FROM
	|	TT_Reservation AS TT_Reservation
	|		INNER JOIN TT_UnionGrouped AS TT_UnionGrouped
	|		ON (TRUE)
	|			AND TT_Reservation.Order = TT_UnionGrouped.Order
	|			AND TT_Reservation._KeyFields = TT_UnionGrouped._KeyFields
	|WHERE
	|	TT_UnionGrouped.Quantity >= 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&_HeaderFields AS _HeaderFields,
	|	TT_Inventory._KeyFields AS _KeyFields,
	|	TT_Inventory.Order AS Order,
	|	CASE
	|		WHEN TT_UnionGrouped.Quantity > 0
	|			THEN TT_UnionGrouped.Quantity
	|		ELSE TT_Inventory.Quantity
	|	END AS Quantity
	|INTO TT_ToBeFilled
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_UnionGrouped AS TT_UnionGrouped
	|		ON (TRUE)
	|			AND TT_Inventory.Order = TT_UnionGrouped.Order
	|			AND TT_Inventory._KeyFields = TT_UnionGrouped._KeyFields
	|WHERE
	|	TT_UnionGrouped.Quantity <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_Inventory._KeyFields AS _KeyFields,
	|	TT_Inventory._AmountFields AS _AmountFields,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.Quantity AS Quantity
	|INTO TT_ToBeAllocated
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_UnionGrouped AS TT_UnionGrouped
	|		ON TRUE
	|			AND TT_Inventory.Order = TT_UnionGrouped.Order
	|			AND TT_Inventory._KeyFields = TT_UnionGrouped._KeyFields
	|WHERE
	|	(FALSE
	|			OR TT_UnionGrouped._AmountFields <> 0
	|			OR TT_UnionGrouped.Quantity <> 0)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_AlreadyFilled._KeyFields AS _KeyFields,
	|	TT_AlreadyFilled._AmountFields AS _AmountFields,
	|	TT_AlreadyFilled.Order AS Order,
	|	TT_AlreadyFilled.SalesOrder AS SalesOrder,
	|	TT_AlreadyFilled.Quantity AS Quantity
	|FROM
	|	TT_AlreadyFilled AS TT_AlreadyFilled
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&_HeaderFields AS _HeaderFields,
	|	TT_ToBeFilled._KeyFields AS _KeyFields,
	|	TT_ToBeFilled.Order AS Order,
	|	TT_ToBeFilled.Quantity AS Quantity
	|FROM
	|	TT_ToBeFilled AS TT_ToBeFilled
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ToBeAllocated._KeyFields AS _KeyFields,
	|	TT_ToBeAllocated._AmountFields AS _AmountFields,
	|	TT_ToBeAllocated.Order AS Order,
	|	TT_ToBeAllocated.Quantity AS Quantity
	|FROM
	|	TT_ToBeAllocated AS TT_ToBeAllocated";
	
	If TypeOf(DocObject) <> Type("DocumentObject.GoodsReceipt") Then
		Query.SetParameter("BasisDocument", DocObject.BasisDocument);
	EndIf;
	
	Query.SetParameter("Inventory", DocObject[Parameters.TableName]);
	Query.SetParameter("InventoryReservation", DocObject[Parameters.ReservationTableName]);
	
	For Each HeaderField In Parameters.HeaderFields Do
		If ValueIsFilled(HeaderField.Value) And TypeOf(HeaderField.Value) = Type("String") Then
			Query.SetParameter(HeaderField.Key, DocObject[HeaderField.Value]);
		Else
			Query.SetParameter(HeaderField.Key, HeaderField.Value);
		EndIf;
	EndDo;
	
	ReplaceWithRealFieldNames(Query, Parameters);
	
	Results = Query.ExecuteBatch();
	ResultsCount = Results.Count();
	
	Parameters.Insert("Table_AlreadyFilled",	Results[ResultsCount - 3].Unload());
	Parameters.Insert("Table_ToBeFilled",		Results[ResultsCount - 2].Unload());
	Parameters.Insert("Table_ToBeAllocated",	Results[ResultsCount - 1].Unload());
	
EndProcedure

Procedure ReplaceWithRealFieldNames(Query, Parameters)
	
	NewQueryLines = New Array;
	
	For LineCounter = 1 To StrLineCount(Query.Text) Do
		
		CurrentLine = StrGetLine(Query.Text, LineCounter);
		
		If StrFind(CurrentLine, "_KeyFields") > 0 Then
			
			For Each KeyField In Parameters.KeyFields Do
				
				NewQueryLines.Add(StrReplace(CurrentLine, "_KeyFields", KeyField));
				
			EndDo;
			
		ElsIf StrFind(CurrentLine, "_AmountFields") > 0 Then
			
			For Each AmountField In Parameters.AmountFields Do
				NewQueryLines.Add(StrReplace(CurrentLine, "_AmountFields", AmountField));
			EndDo;
			
		ElsIf StrFind(CurrentLine, "_HeaderFields") > 0 Then
			
			For Each HeaderField In Parameters.HeaderFields Do
				If Query.Parameters.Property(HeaderField.Key) Then
					CurrentLineCopy = StrReplace(CurrentLine, "_HeaderFieldsValue", HeaderField.Value);
					NewQueryLines.Add(StrReplace(CurrentLineCopy, "_HeaderFields", HeaderField.Key));
				EndIf;
			EndDo;
		ElsIf StrFind(CurrentLine, "_OrderFields") > 0 Then
			
			If Parameters.UseOrder Then
				NewQueryLines.Add(StrReplace(CurrentLine, "_OrderFields", "InventoryDocTable.Order AS Order,"));
			Else
				NewQueryLines.Add(StrReplace(CurrentLine, "_OrderFields", "&BasisDocument AS Order,"));
			EndIf;
		Else
			
			NewQueryLines.Add(CurrentLine);
			
		EndIf;
		
	EndDo;
	
	Query.Text = StrConcat(NewQueryLines, Chars.LF);
	
EndProcedure

Procedure GetBalancesTable(Parameters, DocObject, UseSalesOrder = False)
	
	Query = New Query;
	Query.TempTablesManager = Parameters.TempTablesManager;
	
	If TransactionActive() Then
		LockRegisterBackorders(Query, Parameters);
	EndIf;
	
	If TypeOf(DocObject) = Type("DocumentObject.SupplierInvoice") Then
		
		Query.Text = BalancesTableSupplierInvoiceQueryText();
		
		Query.SetParameter("UseBalance",			Parameters.UseBalance);
		Query.SetParameter("Company", 				DocObject.Company);
		Query.SetParameter("BasisDocument",			DocObject.BasisDocument);
		Query.SetParameter("Date", 					DocObject.Date);
		Query.SetParameter("ProductionProducts",	DocObject[Parameters.TableName].Unload());

	// begin Drive.FullVersion

	ElsIf TypeOf(DocObject) = Type("DocumentObject.Manufacturing") Then

		Query.Text = BalancesTableManufacturingQueryText();
		
		Query.SetParameter("UseBalance",			Parameters.UseBalance);
		Query.SetParameter("Company", 				DocObject.Company);
		Query.SetParameter("BasisDocument",			DocObject.BasisDocument);
		Query.SetParameter("ProductionProducts",	DocObject[Parameters.TableName].Unload());
		
	// end Drive.FullVersion
	
	ElsIf TypeOf(DocObject) = Type("DocumentObject.Production") Then
	
		Query.Text = BalancesTableProductionQueryText();
		
		Query.SetParameter("UseBalance",				Parameters.UseBalance);
		Query.SetParameter("Company", 					DocObject.Company);
		Query.SetParameter("BasisDocument",				DocObject.BasisDocument);
		Query.SetParameter("ProductsStructuralUnit",	DocObject.ProductsStructuralUnit);
		Query.SetParameter("ProductionProducts",		DocObject[Parameters.TableName].Unload());
		
	ElsIf TypeOf(DocObject) = Type("DocumentObject.GoodsReceipt") Then
		
		Query.Text = BalancesTableGoodsReceiptQueryText();
		
		Query.SetParameter("UseBalance",			Parameters.UseBalance);
		Query.SetParameter("Company", 				DocObject.Company);
		Query.SetParameter("Date", 					DocObject.Date);
		Query.SetParameter("ProductionProducts",	DocObject[Parameters.TableName].Unload());
		
	EndIf;
	
	Query.Text = Query.Text + "SELECT
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	MIN(SalesOrderInventory.ShipmentDate) AS ShipmentDate,
	|	SalesOrderInventory.Ref AS SalesOrder
	|INTO TemporaryTableShipmentDates
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref IN
	|			(SELECT
	|				TemporaryTableBackordersBalances.SalesOrder
	|			FROM
	|				TemporaryTableBackordersBalances AS TemporaryTableBackordersBalances)
	|
	|GROUP BY
	|	SalesOrderInventory.Ref,
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.Characteristic
	|
	|UNION ALL
	|
	|SELECT
	|	WorkOrderInventory.Products,
	|	WorkOrderInventory.Characteristic,
	|	MIN(WorkOrder.Start),
	|	WorkOrder.Ref
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|		INNER JOIN Document.WorkOrder.Inventory AS WorkOrderInventory
	|		ON (WorkOrderInventory.Ref = WorkOrder.Ref)
	|WHERE
	|	WorkOrder.Ref IN
	|			(SELECT
	|				TemporaryTableBackordersBalances.SalesOrder
	|			FROM
	|				TemporaryTableBackordersBalances AS TemporaryTableBackordersBalances)
	|
	|GROUP BY
	|	WorkOrderInventory.Characteristic,
	|	WorkOrderInventory.Products,
	|	WorkOrder.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Backorders.SalesOrder AS SalesOrder,
	|	Backorders.Products AS Products,
	|	Backorders.Characteristic AS Characteristic,
	|	Backorders.SupplySource AS Order,
	|	SUM(Backorders.Quantity) AS Quantity
	|FROM
	|	AccumulationRegister.Backorders AS Backorders
	|		INNER JOIN TemporaryTablePlacement AS TemporaryTablePlacement
	|		ON Backorders.Company = TemporaryTablePlacement.Company
	|			AND Backorders.Products = TemporaryTablePlacement.Products
	|			AND Backorders.Characteristic = TemporaryTablePlacement.Characteristic
	|			AND Backorders.Recorder = TemporaryTablePlacement.SupplySource
	|
	|GROUP BY
	|	Backorders.SalesOrder,
	|	Backorders.Products,
	|	Backorders.Characteristic,
	|	Backorders.SupplySource
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableBackordersBalances.SalesOrder AS SalesOrder,
	|	TemporaryTableBackordersBalances.Company AS Company,
	|	TemporaryTableBackordersBalances.Products AS Products,
	|	TemporaryTableBackordersBalances.SupplySource AS Order,
	|	TemporaryTableBackordersBalances.Quantity AS Quantity,
	|	TemporaryTableBackordersBalances.Characteristic AS Characteristic,
	|	ISNULL(TemporaryTableShipmentDates.ShipmentDate, &ControlTime) AS ShipmentDate
	|FROM
	|	TemporaryTableBackordersBalances AS TemporaryTableBackordersBalances
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON TemporaryTableBackordersBalances.Products = CatalogProducts.Ref
	|		LEFT JOIN TemporaryTableShipmentDates AS TemporaryTableShipmentDates
	|		ON TemporaryTableBackordersBalances.Products = TemporaryTableShipmentDates.Products
	|			AND TemporaryTableBackordersBalances.Characteristic = TemporaryTableShipmentDates.Characteristic
	|			AND TemporaryTableBackordersBalances.SalesOrder = TemporaryTableShipmentDates.SalesOrder
	|
	|ORDER BY
	|	ShipmentDate";
	
	Query.SetParameter("ControlPeriod", Date('39991231'));
	Query.SetParameter("ControlTime", Date('00010101'));
	Query.SetParameter("Ref", DocObject.Ref);
	Query.SetParameter("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));

	ArrayResults = Query.ExecuteBatch();
	Count = ArrayResults.Count();
	
	Parameters.Insert("Table_Balances", ArrayResults[Count-1].Unload());
	Parameters.Insert("Table_Orders", ArrayResults[Count-2].Unload());

EndProcedure

Procedure LockRegisterBackorders(Query, Parameters)
	
	Query.Text = 
	"SELECT
	|	TT_ToBeFilled.Company AS Company,
	|	TT_ToBeFilled.Products AS Products,
	|	TT_ToBeFilled.Characteristic AS Characteristic,
	|	TT_ToBeFilled.Order AS SupplySource
	|FROM
	|	TT_ToBeFilled AS TT_ToBeFilled
	|WHERE
	|	TT_ToBeFilled.Order <> UNDEFINED
	|
	|GROUP BY
	|	TT_ToBeFilled.Company,
	|	TT_ToBeFilled.Products,
	|	TT_ToBeFilled.Characteristic,
	|	TT_ToBeFilled.Order";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Backorders");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();

	EndProcedure

// begin Drive.FullVersion

Function BalancesTableManufacturingQueryText()
	
	Return
	"SELECT
	|	ProductionProducts.Products AS Products,
	|	ProductionProducts.Characteristic AS Characteristic,
	|	ProductionProducts.MeasurementUnit AS MeasurementUnit,
	|	ProductionProducts.Quantity AS Quantity
	|INTO TemporaryTableProductionPre
	|FROM
	|	&ProductionProducts AS ProductionProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	ProductionProducts.Products AS Products,
	|	ProductionProducts.Characteristic AS Characteristic,
	|	CASE
	|		WHEN &BasisDocument = VALUE(Document.ProductionOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE &BasisDocument
	|	END AS SupplySource,
	|	SUM(ProductionProducts.Quantity * ISNULL(CatalogUOM.Factor, 1)) AS Quantity
	|INTO TemporaryTablePlacement
	|FROM
	|	TemporaryTableProductionPre AS ProductionProducts
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON ProductionProducts.MeasurementUnit = CatalogUOM.Ref
	|
	|GROUP BY
	|	ProductionProducts.Products,
	|	ProductionProducts.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BackordersBalances.Company AS Company,
	|	BackordersBalances.Products AS Products,
	|	BackordersBalances.Characteristic AS Characteristic,
	|	BackordersBalances.SalesOrder AS SalesOrder,
	|	BackordersBalances.SupplySource AS SupplySource,
	|	BackordersBalances.QuantityBalance AS QuantityBalance
	|INTO BackordersBalancesPre
	|FROM
	|	AccumulationRegister.Backorders.Balance(
	|			&ControlTime,
	|			(Company, Products, Characteristic, SupplySource) IN
	|				(SELECT
	|					TableProduction.Company AS Company,
	|					TableProduction.Products AS Products,
	|					TableProduction.Characteristic AS Characteristic,
	|					TableProduction.SupplySource AS SupplySource
	|				FROM
	|					TemporaryTablePlacement AS TableProduction
	|				WHERE
	|					TableProduction.SupplySource <> UNDEFINED)) AS BackordersBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsBackorders.Company,
	|	DocumentRegisterRecordsBackorders.Products,
	|	DocumentRegisterRecordsBackorders.Characteristic,
	|	DocumentRegisterRecordsBackorders.SalesOrder,
	|	DocumentRegisterRecordsBackorders.SupplySource,
	|	CASE
	|		WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|		ELSE -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|	END
	|FROM
	|	AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|WHERE
	|	&UseBalance
	|	AND DocumentRegisterRecordsBackorders.Recorder = &Ref
	|	AND DocumentRegisterRecordsBackorders.Period <= &ControlPeriod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BackordersBalancesPre.Company AS Company,
	|	BackordersBalancesPre.Products AS Products,
	|	BackordersBalancesPre.Characteristic AS Characteristic,
	|	BackordersBalancesPre.SalesOrder AS SalesOrder,
	|	BackordersBalancesPre.SupplySource AS SupplySource,
	|	SUM(BackordersBalancesPre.QuantityBalance) AS Quantity
	|INTO BackordersBalances
	|FROM
	|	BackordersBalancesPre AS BackordersBalancesPre
	|
	|GROUP BY
	|	BackordersBalancesPre.Company,
	|	BackordersBalancesPre.Products,
	|	BackordersBalancesPre.Characteristic,
	|	BackordersBalancesPre.SalesOrder,
	|	BackordersBalancesPre.SupplySource
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BackordersBalances.SalesOrder AS SalesOrder,
	|	TableProduction.Company AS Company,
	|	TableProduction.Products AS Products,
	|	BackordersBalances.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource,
	|	ISNULL(BackordersBalances.Quantity, 0) AS Quantity
	|INTO TemporaryTableBackordersBalances
	|FROM
	|	TemporaryTablePlacement AS TableProduction
	|		LEFT JOIN BackordersBalances AS BackordersBalances
	|		ON TableProduction.Company = BackordersBalances.Company
	|			AND TableProduction.Products = BackordersBalances.Products
	|			AND TableProduction.Characteristic = BackordersBalances.Characteristic
	|			AND TableProduction.SupplySource = BackordersBalances.SupplySource
	|WHERE
	|	BackordersBalances.SalesOrder IS NOT NULL 
	|	AND TableProduction.SupplySource <> UNDEFINED
	|;";

EndFunction

// end Drive.FullVersion

Function BalancesTableProductionQueryText()
	
	Return
	"SELECT
	|	ProductionProducts.Products AS Products,
	|	ProductionProducts.Characteristic AS Characteristic,
	|	ProductionProducts.MeasurementUnit AS MeasurementUnit,
	|	ProductionProducts.Quantity AS Quantity
	|INTO TemporaryTableProductionPre
	|FROM
	|	&ProductionProducts AS ProductionProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	CAST(&ProductsStructuralUnit AS Catalog.BusinessUnits) AS ProductsStructuralUnitToWarehouse,
	|	ProductionProducts.Products AS Products,
	|	ProductionProducts.Characteristic AS Characteristic,
	|	&BasisDocument AS SupplySource,
	|	SUM(ProductionProducts.Quantity * ISNULL(CatalogUOM.Factor, 1)) AS Quantity
	|INTO TemporaryTablePlacement
	|FROM
	|	TemporaryTableProductionPre AS ProductionProducts
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON ProductionProducts.MeasurementUnit = CatalogUOM.Ref
	|
	|GROUP BY
	|	ProductionProducts.Products,
	|	ProductionProducts.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BackordersBalances.Company AS Company,
	|	BackordersBalances.Products AS Products,
	|	BackordersBalances.Characteristic AS Characteristic,
	|	BackordersBalances.SalesOrder AS SalesOrder,
	|	BackordersBalances.SupplySource AS SupplySource,
	|	BackordersBalances.QuantityBalance AS QuantityBalance
	|INTO BackordersBalancesPre
	|FROM
	|	AccumulationRegister.Backorders.Balance(
	|			&ControlTime,
	|			(Company, Products, Characteristic, SupplySource) IN
	|				(SELECT
	|					TableProduction.Company AS Company,
	|					TableProduction.Products AS Products,
	|					TableProduction.Characteristic AS Characteristic,
	|					TableProduction.SupplySource AS SupplySource
	|				FROM
	|					TemporaryTablePlacement AS TableProduction
	|				WHERE
	|					TableProduction.SupplySource <> UNDEFINED)) AS BackordersBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsBackorders.Company,
	|	DocumentRegisterRecordsBackorders.Products,
	|	DocumentRegisterRecordsBackorders.Characteristic,
	|	DocumentRegisterRecordsBackorders.SalesOrder,
	|	DocumentRegisterRecordsBackorders.SupplySource,
	|	CASE
	|		WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|		ELSE -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|	END
	|FROM
	|	AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|WHERE
	|	&UseBalance
	|	AND DocumentRegisterRecordsBackorders.Recorder = &Ref
	|	AND DocumentRegisterRecordsBackorders.Period <= &ControlPeriod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableBackordersBalances.Company AS Company,
	|	TemporaryTableBackordersBalances.SalesOrder AS SalesOrder,
	|	TemporaryTableBackordersBalances.Products AS Products,
	|	TemporaryTableBackordersBalances.Characteristic AS Characteristic,
	|	TemporaryTableBackordersBalances.SupplySource AS SupplySource,
	|	SUM(TemporaryTableBackordersBalances.QuantityBalance) AS Quantity
	|INTO BackordersBalances
	|FROM
	|	BackordersBalancesPre AS TemporaryTableBackordersBalances
	|
	|GROUP BY
	|	TemporaryTableBackordersBalances.Company,
	|	TemporaryTableBackordersBalances.SalesOrder,
	|	TemporaryTableBackordersBalances.Products,
	|	TemporaryTableBackordersBalances.Characteristic,
	|	TemporaryTableBackordersBalances.SupplySource
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Company AS Company,
	|	BackordersBalances.SalesOrder AS SalesOrder,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource,
	|	ISNULL(BackordersBalances.Quantity, 0) AS Quantity
	|INTO TemporaryTableBackordersBalances
	|FROM
	|	TemporaryTablePlacement AS TableProduction
	|		LEFT JOIN BackordersBalances AS BackordersBalances
	|		ON TableProduction.Company = BackordersBalances.Company
	|			AND TableProduction.Products = BackordersBalances.Products
	|			AND TableProduction.Characteristic = BackordersBalances.Characteristic
	|			AND TableProduction.SupplySource = BackordersBalances.SupplySource
	|WHERE
	|	TableProduction.SupplySource <> UNDEFINED
	|	AND BackordersBalances.SalesOrder IS NOT NULL 
	|	AND TableProduction.ProductsStructuralUnitToWarehouse.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|;";
	
EndFunction

Function BalancesTableSupplierInvoiceQueryText()
	
	Return
		"SELECT
		|	ProductionProducts.Products AS Products,
		|	ProductionProducts.Characteristic AS Characteristic,
		|	ProductionProducts.MeasurementUnit AS MeasurementUnit,
		|	ProductionProducts.Order AS Order,
		|	ProductionProducts.Quantity AS Quantity
		|INTO TemporaryTableProductionPre
		|FROM
		|	&ProductionProducts AS ProductionProducts
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	&Company AS Company,
		|	InventoryProducts.Products AS Products,
		|	InventoryProducts.Characteristic AS Characteristic,
		|	InventoryProducts.Order AS SupplySource,
		|	SUM(InventoryProducts.Quantity * ISNULL(CatalogUOM.Factor, 1)) AS Quantity
		|INTO TemporaryTablePlacement
		|FROM
		|	TemporaryTableProductionPre AS InventoryProducts
		|		LEFT JOIN Catalog.UOM AS CatalogUOM
		|		ON InventoryProducts.MeasurementUnit = CatalogUOM.Ref
		|
		|GROUP BY
		|	InventoryProducts.Products,
		|	InventoryProducts.Characteristic,
		|	InventoryProducts.Order
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	BackordersBalances.Company AS Company,
		|	BackordersBalances.Products AS Products,
		|	BackordersBalances.Characteristic AS Characteristic,
		|	BackordersBalances.SalesOrder AS SalesOrder,
		|	BackordersBalances.SupplySource AS SupplySource,
		|	BackordersBalances.QuantityBalance AS QuantityBalance
		|INTO BackordersBalancesPre
		|FROM
		|	AccumulationRegister.Backorders.Balance(
		|			,
		|			(Company, Products, Characteristic, SupplySource) IN
		|				(SELECT
		|					TableBackorders.Company AS Company,
		|					TableBackorders.Products AS Products,
		|					TableBackorders.Characteristic AS Characteristic,
		|					TableBackorders.SupplySource AS SupplySource
		|				FROM
		|					TemporaryTablePlacement AS TableBackorders)) AS BackordersBalances
		|
		|UNION ALL
		|
		|SELECT
		|	DocumentRegisterRecordsBackorders.Company,
		|	DocumentRegisterRecordsBackorders.Products,
		|	DocumentRegisterRecordsBackorders.Characteristic,
		|	DocumentRegisterRecordsBackorders.SalesOrder,
		|	DocumentRegisterRecordsBackorders.SupplySource,
		|	CASE
		|		WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
		|			THEN ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
		|		ELSE -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
		|	END
		|FROM
		|	AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
		|WHERE
		|	&UseBalance
		|	AND DocumentRegisterRecordsBackorders.Recorder = &Ref
		|	AND DocumentRegisterRecordsBackorders.Period <= &ControlPeriod
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	BackordersBalancesPre.Company AS Company,
		|	BackordersBalancesPre.Products AS Products,
		|	BackordersBalancesPre.Characteristic AS Characteristic,
		|	BackordersBalancesPre.SalesOrder AS SalesOrder,
		|	BackordersBalancesPre.SupplySource AS SupplySource,
		|	SUM(BackordersBalancesPre.QuantityBalance) AS Quantity
		|INTO BackordersBalances
		|FROM
		|	BackordersBalancesPre AS BackordersBalancesPre
		|
		|GROUP BY
		|	BackordersBalancesPre.Characteristic,
		|	BackordersBalancesPre.SupplySource,
		|	BackordersBalancesPre.Company,
		|	BackordersBalancesPre.Products,
		|	BackordersBalancesPre.SalesOrder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	TableBackorders.Company AS Company,
		|	BackordersBalances.SalesOrder AS SalesOrder,
		|	TableBackorders.Products AS Products,
		|	TableBackorders.Characteristic AS Characteristic,
		|	TableBackorders.SupplySource AS SupplySource,
		|	ISNULL(BackordersBalances.Quantity, 0) AS Quantity
		|INTO TemporaryTableBackordersBalances
		|FROM
		|	TemporaryTablePlacement AS TableBackorders
		|		LEFT JOIN BackordersBalances AS BackordersBalances
		|		
		|		ON TableBackorders.Company = BackordersBalances.Company
		|			AND TableBackorders.Products = BackordersBalances.Products
		|			AND TableBackorders.Characteristic = BackordersBalances.Characteristic
		|			AND TableBackorders.SupplySource = BackordersBalances.SupplySource
		|WHERE
		|	BackordersBalances.SalesOrder IS NOT NULL
		|;";
	
EndFunction

Function BalancesTableGoodsReceiptQueryText()
	
	Return
		"SELECT
		|	ProductionProducts.Products AS Products,
		|	ProductionProducts.Characteristic AS Characteristic,
		|	ProductionProducts.MeasurementUnit AS MeasurementUnit,
		|	ProductionProducts.Order AS Order,
		|	ProductionProducts.Quantity AS Quantity
		|INTO TemporaryTableProductionPre
		|FROM
		|	&ProductionProducts AS ProductionProducts
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	&Company AS Company,
		|	InventoryProducts.Products AS Products,
		|	InventoryProducts.Characteristic AS Characteristic,
		|	InventoryProducts.Order AS SupplySource,
		|	SUM(InventoryProducts.Quantity * ISNULL(CatalogUOM.Factor, 1)) AS Quantity
		|INTO TemporaryTablePlacement
		|FROM
		|	TemporaryTableProductionPre AS InventoryProducts
		|		LEFT JOIN Catalog.UOM AS CatalogUOM
		|		ON InventoryProducts.MeasurementUnit = CatalogUOM.Ref
		|
		|GROUP BY
		|	InventoryProducts.Products,
		|	InventoryProducts.Characteristic,
		|	InventoryProducts.Order
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Balance.Company AS Company,
		|	Balance.Products AS Products,
		|	Balance.Characteristic AS Characteristic,
		|	Balance.SalesOrder AS SalesOrder,
		|	Balance.SupplySource AS SupplySource,
		|	Balance.QuantityBalance AS QuantityBalance
		|INTO BalanceRecords
		|FROM
		|	AccumulationRegister.Backorders.Balance(
		|			&ControlTime,
		|			(Company, Products, Characteristic, SupplySource) IN
		|				(SELECT
		|					TableBackorders.Company AS Company,
		|					TableBackorders.Products AS Products,
		|					TableBackorders.Characteristic AS Characteristic,
		|					TableBackorders.SupplySource AS SupplySource
		|				FROM
		|					TemporaryTablePlacement AS TableBackorders)) AS Balance
		|
		|UNION ALL
		|
		|SELECT
		|	DocumentRecords.Company,
		|	DocumentRecords.Products,
		|	DocumentRecords.Characteristic,
		|	DocumentRecords.SalesOrder,
		|	DocumentRecords.SupplySource,
		|	CASE
		|		WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Expense)
		|			THEN ISNULL(DocumentRecords.Quantity, 0)
		|		ELSE -ISNULL(DocumentRecords.Quantity, 0)
		|	END
		|FROM
		|	AccumulationRegister.Backorders AS DocumentRecords
		|WHERE
		|	&UseBalance
		|	AND DocumentRecords.Recorder = &Ref
		|	AND DocumentRecords.Period <= &ControlPeriod
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Balance.Company AS Company,
		|	Balance.Products AS Products,
		|	Balance.Characteristic AS Characteristic,
		|	Balance.SalesOrder AS SalesOrder,
		|	Balance.SupplySource AS SupplySource,
		|	SUM(Balance.QuantityBalance) AS Quantity
		|INTO Balance
		|FROM
		|	BalanceRecords AS Balance
		|
		|GROUP BY
		|	Balance.Company,
		|	Balance.Products,
		|	Balance.Characteristic,
		|	Balance.SalesOrder,
		|	Balance.SupplySource
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	VALUE(AccumulationRecordType.Expense) AS RecordType,
		|	Table.Company AS Company,
		|	Balance.SalesOrder AS SalesOrder,
		|	Table.Products AS Products,
		|	Table.Characteristic AS Characteristic,
		|	Table.SupplySource AS SupplySource,
		|	ISNULL(Balance.Quantity, 0) AS Quantity
		|INTO TemporaryTableBackordersBalances
		|FROM
		|	TemporaryTablePlacement AS Table
		|		LEFT JOIN Balance AS Balance
		|		ON Table.Company = Balance.Company
		|			AND Table.Products = Balance.Products
		|			AND Table.Characteristic = Balance.Characteristic
		|			AND Table.SupplySource = Balance.SupplySource
		|WHERE
		|	Balance.SalesOrder IS NOT NULL
		|;";
	
EndFunction

Procedure AllocateAmounts(Parameters)
	
	KeyFieldsString = StringFunctionsClientServer.StringFromSubstringArray(Parameters.KeyFields);
	
	SearchFilter = New Structure(KeyFieldsString);
	
	For Each ToBeAllocatedRow In Parameters.Table_ToBeAllocated Do
		
		FillPropertyValues(SearchFilter, ToBeAllocatedRow);
		
		DestinationRows = Parameters.Table_AlreadyFilled.FindRows(SearchFilter);
		
		For Each AmountField In Parameters.AmountFields Do
			
			AmountToBeAllocated = ToBeAllocatedRow[AmountField];
			AmountActuallyAllocated = 0;
			RoundingError = 0;
			DestinationRow = Undefined;
			
			For Each DestinationRow In DestinationRows Do
				
				PreciseAmount = Round(AmountToBeAllocated * DestinationRow.Quantity / ToBeAllocatedRow.Quantity, 27);
				DestinationRow[AmountField] = Round(PreciseAmount + RoundingError, 2);
				AmountActuallyAllocated = AmountActuallyAllocated + DestinationRow[AmountField];
				RoundingError = PreciseAmount - DestinationRow[AmountField];
				
			EndDo;
			
			If AmountActuallyAllocated <> AmountToBeAllocated
				And DestinationRow <> Undefined Then
				
				DestinationRow[AmountField] = DestinationRow[AmountField] + AmountToBeAllocated - AmountActuallyAllocated;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function GetFieldsToSkip(Parameters, DoesntUseBatch)
	
	FieldsToSkip = New Array;
	FieldsToSkip.Add("SalesOrder");
	FieldsToSkip.Add("SerialNumbers");
	FieldsToSkip.Add("Order");
	FieldsToSkip.Add("Quantity");
	FieldsToSkip.Add("MeasurementUnit");
	
	If DoesntUseBatch Then
		FieldsToSkip.Add("Batch");
	EndIf;
	
	If Parameters.DocMetadata.Name = "Production"
		And Parameters.TableName = "Products" Then
		FieldsToSkip.Add("CostPercentage");	
	EndIf;
	
	Return FieldsToSkip;
	
EndFunction

Function GetTableForReservationTreeFilling(Parameters, DocObjectStructure)
	
	Query = New Query;
	
	Query.TempTablesManager = Parameters.TempTablesManager;
	
	Query.Text =
	
	"SELECT
	|	InventoryDocTable._KeyFields AS _KeyFields,
	|	InventoryDocTable._AmountFields AS _AmountFields,
	|	InventoryDocTable.MeasurementUnit AS MeasurementUnit,
	|	_OrderFields
	|	InventoryDocTable.Quantity AS Quantity
	|INTO TT_Inventory
	|FROM
	|	&Inventory AS InventoryDocTable
	|;
	|SELECT
	|	TT_Inventory._KeyFields AS _KeyFields,
	|	TT_Inventory.Order AS Order,
	|	SUM(TT_Inventory._AmountFields) AS _AmountFields,
	|	CatalogProducts.MeasurementUnit AS _BaseMeasurementUnit,
	|	SUM(TT_Inventory.Quantity) AS _BaseQuantity,
	|	SUM(TT_Inventory.Quantity * ISNULL(UOM.Factor, 1)) AS Quantity
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (TT_Inventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TT_Inventory.MeasurementUnit = UOM.Ref
	|
	|GROUP BY
	|	TT_Inventory._KeyFields,
	|	TT_Inventory.Order,
	|	CatalogProducts.MeasurementUnit";
	
	Query.SetParameter("Inventory", DocObjectStructure.Inventory);
	Query.SetParameter("BasisDocument", ?(TypeOf(DocObjectStructure) = Type("DocumentObject.GoodsReceipt"), Undefined,
		DocObjectStructure.BasisDocument));
	
	ReplaceWithRealFieldNames(Query, Parameters);
	
	Return Query.Execute().Unload();

EndFunction

Procedure CheckSalesOrderDates(Reservation)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProductionReservation.Products AS Products,
	|	ProductionReservation.Characteristic AS Characteristic,
	|	ProductionReservation.SalesOrder AS SalesOrder
	|INTO TempTablesReservationPre
	|FROM
	|	&Reservation AS ProductionReservation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionReservation.Products AS Products,
	|	ProductionReservation.Characteristic AS Characteristic,
	|	ProductionReservation.SalesOrder AS SalesOrder
	|INTO TempTablesReservation
	|FROM
	|	TempTablesReservationPre AS ProductionReservation
	|
	|GROUP BY
	|	ProductionReservation.Products,
	|	ProductionReservation.Characteristic,
	|	ProductionReservation.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	COUNT(DISTINCT SalesOrderInventory.ShipmentDate) AS ShipmentDate
	|FROM
	|	TempTablesReservation AS TempTablesReservation
	|		INNER JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|		ON TempTablesReservation.SalesOrder = SalesOrderInventory.Ref
	|			AND TempTablesReservation.Products = SalesOrderInventory.Products
	|			AND TempTablesReservation.Characteristic = SalesOrderInventory.Characteristic
	|
	|GROUP BY
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.Characteristic
	|
	|HAVING
	|	COUNT(DISTINCT SalesOrderInventory.ShipmentDate) > 1";
	
	Query.SetParameter("Reservation", Reservation);

	If Not Query.Execute().IsEmpty() Then
		CommonClientServer.MessageToUser(
			NStr("en = 'This document includes products reserved for Sales orders. A Sales order has different shipment dates
				|for the products. To ensure the products are reserved and received for the Sales orders correctly,
				|on the Goods tab, click More options > Inventory reservation and review the inventory reservation details.'; 
				|ru = 'Этот документ содержит номенклатуру, зарезервированную под заказы покупателей. В заказе покупателя указаны разные даты отгрузки
				|номенклатуры. Чтобы убедиться, что номенклатура корректно зарезервирована и получена под заказ покупателя,
				|на вкладке ""Товары"" нажмите Еще > Резервирование запасов и посмотрите сведения о резервировании запасов.';
				|pl = 'Ten dokument obejmuje produkty zarezerwowane dla Zamówień sprzedaży. Zamówienie sprzedaży ma różne daty wysyłki
				|dla produktów. Aby upewnić się że produkty są poprawnie zarezerwowane lub otrzymane dla Zamówień sprzedaży,
				|na karcie Towary, kliknij Więcej > Rezerwacja zapasów i przegląd szczegółów rezerwacji zapasów.';
				|es_ES = 'Este documento incluye los productos reservados para las órdenes de venta. Una orden de venta tiene diferentes fechas de envío para los productos. Para asegurarse de que los productos se reservan y se reciben para las órdenes de venta correctamente, en la pestaña Productos, haga clic en Más posibilidades > Reserva de stock y revise los detalles de la reserva de stock.';
				|es_CO = 'Este documento incluye los productos reservados para las órdenes de venta. Una orden de venta tiene diferentes fechas de envío para los productos. Para asegurarse de que los productos se reservan y se reciben para las órdenes de venta correctamente, en la pestaña Productos, haga clic en Más posibilidades > Reserva de stock y revise los detalles de la reserva de stock.';
				|tr = 'Bu belge Satış siparişleri için rezerve edilmiş ürünler içeriyor. Satış siparişlerinden biri ürünler için 
				|farklı sevkiyat tarihleri içeriyor. Satış siparişleri için ürünlerin doğru şekilde rezerve edilmesi ve alınması için
				| Ürünler sekmesinde Diğer seçenekler > Stok rezervasyonu''na tıklayın ve stok rezervasyonu bilgilerini gözden geçirin.';
				|it = 'Questo documento include articoli riservati per gli Ordini cliente. Un Ordine cliente ha diverse date di spedizione
				| per gli articoli. Per assicurarsi che gli articoli siano riservati e ricevuti correttamente per gli Ordini cliente,
				|nella scheda Merci cliccare Altre opzioni > riserva delle scorte e rivedere i dettagli della riserva delle scorte.';
				|de = 'Dieses Dokument enthält Produkte reserviert für Kundenaufträge. Ein Kundenauftrag hat unterschiedliche Lieferdaten
				|für die Produkte. Um sicherzustellen, dass die Produkte reserviert und für die Kundenaufträge richtig empfangen sind,
				| klicken Sie auf der Registerkarte Waren auf Mehr > Bestandsreservierung und überprüfen Sie die Details der Bestandsreservierung.'"));
	EndIf;
	
EndProcedure

#EndRegion