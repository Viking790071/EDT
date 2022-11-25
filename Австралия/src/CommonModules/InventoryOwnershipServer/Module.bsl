#Region Public

#Region InfobaseUpdate

Function InfobaseUpdate_FillOwnershipInRegister(RegisterName) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Register_RegisterName.Recorder AS Recorder,
	|	Register_RegisterName.LineNumber AS LineNumber,
	|	Register_RegisterName.Company AS Company,
	|	CatalogProductsBatches.DeleteStatus AS BatchStatus,
	|	CatalogProductsBatches.DeleteBatchOwner AS BatchCounterparty
	|FROM
	|	AccumulationRegister._RegisterName AS Register_RegisterName
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogProductsBatches
	|		ON Register_RegisterName.Batch = CatalogProductsBatches.Ref
	|WHERE
	|	Register_RegisterName.Ownership = VALUE(Catalog.InventoryOwnership.EmptyRef)
	|TOTALS BY
	|	Recorder";
	
	Query.Text = StrReplace(Query.Text, "_RegisterName", RegisterName);
	
	SelRef = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	CashedValues = New Map;
	
	While SelRef.Next() Do
		
		RecordSet = AccumulationRegisters[RegisterName].CreateRecordSet();
		RecordSet.Filter.Recorder.Set(SelRef.Recorder);
		RecordSet.Read();
		
		Sel = SelRef.Select();
		
		While Sel.Next() Do
			Record = RecordSet[Sel.LineNumber - 1];
			Record.Ownership = InfobaseUpdate_BatchOwnership(
				Sel.BatchStatus, Sel.BatchCounterparty, Sel.Company, CashedValues);
		EndDo;
		
		Try
			
			InfobaseUpdate.WriteRecordSet(RecordSet);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot post document ""%1"". Details: %2'; ru = 'Не удалось провести документ ""%1"". Подробнее: %2';pl = 'Nie można zatwierdzić dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al enviar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al enviar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi kaydedilemiyor. Ayrıntılar: %2';it = 'Impossibile pubblicare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Buchen des Dokuments ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				SelRef.Recorder,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndFunction

Function InfobaseUpdate_FillOwnershipTable(DocumentName, TableName = "InventoryOwnership",
	Condition = Undefined) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Document_DocumentName.Ref AS Ref
	|FROM
	|	Document._DocumentName AS Document_DocumentName
	|		LEFT JOIN Document._DocumentName._TableName AS _DocumentName_TableName
	|		ON Document_DocumentName.Ref = _DocumentName_TableName.Ref
	|			AND (_DocumentName_TableName.LineNumber = 1)
	|WHERE
	|	Document_DocumentName.Posted
	|	AND _DocumentName_TableName.LineNumber IS NULL
	|	AND &AdditionalCondition";
	
	Query.Text = StrReplace(Query.Text, "_DocumentName", DocumentName);
	Query.Text = StrReplace(Query.Text, "_TableName", TableName);
	
	If Condition = Undefined Then
		Query.SetParameter("AdditionalCondition", True);
	Else
		Query.Text = StrReplace(Query.Text, "&AdditionalCondition", Condition);
	EndIf;
	
	SelRef = Query.Execute().Select();
	
	CashedValues = New Map;
	
	While SelRef.Next() Do
		
		DocObject = SelRef.Ref.GetObject();
		
		ParametersSet = DocumentParameters(DocObject);
		
		For Each Parameters In ParametersSet Do
			
			AddKeyFields(Parameters, DocObject);
			
			UseSerialNumbers = GetFunctionalOption("UseSerialNumbers")
				And GetFunctionalOption("UseSerialNumbersAsInventoryRecordDetails");
			Parameters.Insert("UseSerialNumbers", UseSerialNumbers); 
			
			Parameters.Insert("TempTablesManager", Undefined);
			
			Parameters.Insert("InfobaseUpdate", True);
			
			GetDocumentTables(Parameters, DocObject);
			
			For Each ToBeFilledRow In Parameters.Table_ToBeFilled Do
				
				NewRow = Parameters.Table_AlreadyFilled.Add();
				
				FillPropertyValues(NewRow, ToBeFilledRow);
				
				If ValueIsFilled(ToBeFilledRow.SerialNumber) Then
					NewRow.Quantity = 1;
				Else
					NewRow.Quantity = ToBeFilledRow.Quantity;
				EndIf;
				
				NewRow.Ownership = InfobaseUpdate_BatchOwnership(
					ToBeFilledRow._BatchStatus, ToBeFilledRow._BatchCounterparty, DocObject.Company, CashedValues);
				
			EndDo;
			
			AllocateAmounts(Parameters);
			
			DocObject[Parameters.OwnershipTableName].Load(Parameters.Table_AlreadyFilled);
			
		EndDo;
		
		Try
			
			InfobaseUpdate.WriteObject(DocObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'"),
				DocObject.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				DocObject.Metadata(),
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndFunction

Function InfobaseUpdate_FillMainTableColumn(DocumentName, TableName = "Inventory",
		Condition = Undefined, BatchOwnershipPrefix = "") Export
	
	OwnershipName = BatchOwnershipPrefix + "Ownership";
	BatchName = BatchOwnershipPrefix + "Batch";
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	_DocumentName_TableName.Ref AS Ref,
	|	_DocumentName_TableName.LineNumber AS LineNumber,
	|	CatalogProductsBatches.DeleteStatus AS BatchStatus,
	|	CatalogProductsBatches.DeleteBatchOwner AS BatchCounterparty
	|FROM
	|	Document._DocumentName AS Document_DocumentName
	|		INNER JOIN Document._DocumentName._TableName AS _DocumentName_TableName
	|		ON Document_DocumentName.Ref = _DocumentName_TableName.Ref
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogProductsBatches
	|		ON (_DocumentName_TableName._BatchName = CatalogProductsBatches.Ref)
	|WHERE
	|	Document_DocumentName.Posted
	|	AND _DocumentName_TableName._OwnershipName = VALUE(Catalog.InventoryOwnership.EmptyRef)
	|	AND &AdditionalCondition
	|TOTALS BY
	|	Ref";
	
	If Metadata.Documents[DocumentName].Posting = Metadata.ObjectProperties.Posting.Deny Then
		Query.Text = StrReplace(Query.Text, "Document_DocumentName.Posted", "TRUE");
	EndIf;
	Query.Text = StrReplace(Query.Text, "_DocumentName", DocumentName);
	Query.Text = StrReplace(Query.Text, "_TableName", TableName);
	Query.Text = StrReplace(Query.Text, "_BatchName", BatchName);
	Query.Text = StrReplace(Query.Text, "_OwnershipName", OwnershipName);
	
	If Condition = Undefined Then
		Query.SetParameter("AdditionalCondition", True);
	Else
		Query.Text = StrReplace(Query.Text, "&AdditionalCondition", Condition);
	EndIf;
	
	SelRef = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	CashedValues = New Map;
	
	While SelRef.Next() Do
		
		DocObject = SelRef.Ref.GetObject();
		
		Sel = SelRef.Select();
		
		While Sel.Next() Do
			InventoryRow = DocObject[TableName][Sel.LineNumber - 1];
			InventoryRow[OwnershipName] = InfobaseUpdate_BatchOwnership(
				Sel.BatchStatus, Sel.BatchCounterparty, DocObject.Company, CashedValues);
		EndDo;
		
		Try
			
			InfobaseUpdate.WriteObject(DocObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'"),
				DocObject.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				DocObject.Metadata(),
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndFunction

Function InfobaseUpdate_BatchOwnership(BatchStatus, BatchCounterparty, Company, CashedValues) Export
	
	If BatchStatus = Enums.InventoryOwnershipTypes.CounterpartysInventory Then
		
		CompanyMap = CashedValues.Get(BatchCounterparty);
		If CompanyMap = Undefined Then
			CompanyMap = New Map;
			CashedValues.Insert(BatchCounterparty, CompanyMap);
		EndIf;
		
		Ownership = CompanyMap.Get(Company);
		If Ownership = Undefined Then
			
			ContractKindsList = New ValueList;
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
			
			Contract = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
				BatchCounterparty, Company, ContractKindsList);
			
			If Not ValueIsFilled(Contract) Then
				Contract = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(BatchCounterparty, Company);
			EndIf;
			
			Parameters = New Structure;
			Parameters.Insert("OwnershipType", BatchStatus);
			Parameters.Insert("Counterparty", BatchCounterparty);
			Parameters.Insert("Contract", Contract);
			
			Ownership = Catalogs.InventoryOwnership.GetByParameters(Parameters);
			CompanyMap.Insert(Company, Ownership);
			
		EndIf;
		
	Else
		
		Ownership = CashedValues.Get(Catalogs.Counterparties.EmptyRef());
		If Ownership = Undefined Then
			
			Ownership = Catalogs.InventoryOwnership.OwnInventory();
			CashedValues.Insert(Catalogs.Counterparties.EmptyRef(), Ownership);
			
		EndIf;
		
	EndIf;
	
	Return Ownership;
	
EndFunction

Function InfobaseUpdate_FillProductGLAccounts(DocumentName, TableName = "Inventory",
	Condition = Undefined) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Document_DocumentName.Ref AS Ref,
	|	_DocumentName_TableName.LineNumber AS LineNumber,
	|	_DocumentName_TableName.Products AS Products
	|FROM
	|	Document._DocumentName AS Document_DocumentName
	|		INNER JOIN Document._DocumentName._TableName AS _DocumentName_TableName
	|		ON Document_DocumentName.Ref = _DocumentName_TableName.Ref
	|WHERE
	|	(_DocumentName_TableName.InventoryGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		OR _DocumentName_TableName.InventoryReceivedGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|	AND &AdditionalCondition
	|TOTALS BY
	|	Ref";
	
	Query.Text = StrReplace(Query.Text, "_DocumentName", DocumentName);
	Query.Text = StrReplace(Query.Text, "_TableName", TableName);
	
	If Condition = Undefined Then
		Query.SetParameter("AdditionalCondition", True);
	Else
		Query.Text = StrReplace(Query.Text, "&AdditionalCondition", Condition);
	EndIf;
	
	SelRef = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelRef.Next() Do
		
		DocObject = SelRef.Ref.GetObject();
		
		StructureData = New Structure;
		StructureData.Insert("ObjectParameters",
			GLAccountsInDocuments.GetObjectParametersByMetadata(DocObject, DocObject.Metadata()));
		
		ProductsList = New Array;
		Sel = SelRef.Select();
		While Sel.Next() Do
			ProductsList.Add(Sel.Products);
		EndDo;
		StructureData.Insert("Products", ProductsList);
		
		GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
		
		Sel.Reset();
		While Sel.Next() Do
			
			InventoryRow = DocObject[TableName][Sel.LineNumber - 1];
			ProductGLAccounts = GLAccounts[Sel.Products];
			If Not ValueIsFilled(InventoryRow.InventoryGLAccount) Then
				InventoryRow.InventoryGLAccount = ProductGLAccounts.InventoryGLAccount;
			EndIf;
			If Not ValueIsFilled(InventoryRow.InventoryReceivedGLAccount) Then
				InventoryRow.InventoryReceivedGLAccount = ProductGLAccounts.InventoryReceivedGLAccount;
			EndIf;
			
		EndDo;
		
		Try
			
			InfobaseUpdate.WriteObject(DocObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'"),
				DocObject.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				DocObject.Metadata(),
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndFunction

#EndRegion

Procedure SetMainTableConditionalAppearance(ConditionalAppearance, TableName = "Inventory",
	ColumnName = "Ownership") Export
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object." + TableName + "." + ColumnName,
		,
		DataCompositionComparisonType.NotFilled);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'filled automatically'; ru = 'заполнено автоматически';pl = 'wypełnione automatycznie';es_ES = 'relleno automáticamente';es_CO = 'relleno automáticamente';tr = 'otomatik dolduruldu';it = 'compilato automaticamente';de = 'automatisch gefüllt'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, TableName + ColumnName);
	
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	
EndProcedure

Procedure FillHeaderAttribute(DocObject, WriteMode, Cancel) Export
	
	If WriteMode <> DocumentWriteMode.Posting Then
		Return;
	EndIf;
	
	ParametersSet = DocumentParameters(DocObject);
	
	For Each Parameters In ParametersSet Do
	
		If Parameters.Property("HeaderAttributeName") Then
			HeaderAttributeName = Parameters.HeaderAttributeName;
		ElsIf Parameters.Property("ColumnName") Then
			HeaderAttributeName = Parameters.ColumnName;
		Else
			HeaderAttributeName = "Ownership";
		EndIf;
		
		If Not ValueIsFilled(DocObject[HeaderAttributeName]) Then
			
			DocObject[HeaderAttributeName] = Catalogs.InventoryOwnership.GetByParameters(Parameters, Cancel);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillMainTableColumn(DocObject, WriteMode, Cancel) Export
	
	If WriteMode <> DocumentWriteMode.Posting Then
		Return;
	EndIf;
	
	ParametersSet = DocumentParameters(DocObject);
	
	For Each Parameters In ParametersSet Do
		
		Table = DocObject[Parameters.TableName];
		If Parameters.Property("ColumnName") Then
			ColumnName = Parameters.ColumnName;
		Else
			ColumnName = "Ownership";
		EndIf;
		
		Ownership = Catalogs.InventoryOwnership.GetByParameters(Parameters, Cancel);
		
		If ValueIsFilled(Ownership) Then
			
			For Each TableRow In Table Do
				
				If Not ValueIsFilled(TableRow[ColumnName]) Then
					
					TableRow[ColumnName] = Ownership;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillOwnershipTable(DocObject, WriteMode, Cancel) Export
	
	If WriteMode <> DocumentWriteMode.Posting Then
		Return;
	EndIf;
	
	ParametersSet = DocumentParameters(DocObject);
	
	For Each Parameters In ParametersSet Do
		
		AddKeyFields(Parameters, DocObject);
		
		UseSerialNumbers = GetFunctionalOption("UseSerialNumbers")
			And GetFunctionalOption("UseSerialNumbersAsInventoryRecordDetails");
		Parameters.Insert("UseSerialNumbers", UseSerialNumbers); 
		
		Parameters.Insert("TempTablesManager", New TempTablesManager);
		
		If Not DocObject.Posted
			Or DocObject.AdditionalProperties.Property("ForcedOwnershipFilling")
			Or HeaderAttributesChanged(Parameters, DocObject) Then
			DocObject[Parameters.OwnershipTableName].Clear();
		EndIf;
		
		GetDocumentTables(Parameters, DocObject);
		
		GetBalancesTable(Parameters, DocObject);
		
		FillOwnership(Parameters);
		
		AllocateAmounts(Parameters);
		
		DocObject[Parameters.OwnershipTableName].Load(Parameters.Table_AlreadyFilled);
		
	EndDo;
	
EndProcedure

Function GetDataForInventoryOwnershipForm(DocObject) Export
	
	Data = New Structure;
	
	ParametersSet = DocumentParameters(DocObject);
	
	Parameters = ParametersSet[0];
	
	AddKeyFields(Parameters, DocObject);
	
	UseSerialNumbers = GetFunctionalOption("UseSerialNumbers")
		And GetFunctionalOption("UseSerialNumbersAsInventoryRecordDetails");
	Parameters.Insert("UseSerialNumbers", UseSerialNumbers);
	
	Parameters.Insert("TempTablesManager", New TempTablesManager);
	
	Data.Insert("Parameters", Parameters);
	
	DocObjectStructure = New Structure;
	DocObjectStructure.Insert("Ref", DocObject.Ref);
	DocObjectStructure.Insert("Inventory", DocObject[Parameters.TableName].Unload());
	DocObjectStructure.Insert("SerialNumbers", DocObject[Parameters.SerialNumbersTableName].Unload());
	DocObjectStructure.Insert("InventoryOwnership", DocObject[Parameters.OwnershipTableName].Unload());
	
	Data.Insert("DocObject", DocObjectStructure);
	
	Data.Insert("KeyTable", GetTableForOwnershipTreeFilling(Parameters, DocObject));
	
	GetBalancesTable(Parameters, DocObject);
	
	Parameters.TempTablesManager = Undefined;
	
	Return Data;
	
EndFunction

Function GetBalanceForInventoryOwnershipForm(Parameters, RowKeyData, Ownership) Export
	
	SearchFilter = New Structure(
		"Company,
		|Products,
		|Characteristic,
		|Batch,
		|SerialNumber,
		|StructuralUnit,
		|GoodsIssue,
		|Order");
	SearchFilter.Insert(Parameters.CellFieldName);
	
	SearchFilter.Insert("Ownership", Ownership);
	
	EmptySerialNumber = Catalogs.SerialNumbers.EmptyRef();
	EmptyStructuralUnit = Catalogs.BusinessUnits.EmptyRef();
	EmptyCell = Catalogs.Cells.EmptyRef();
	EmptyGoodsIssue = Documents.GoodsIssue.EmptyRef();
	EmptyOrder = Documents.SalesOrder.EmptyRef();
	
	FillPropertyValues(SearchFilter, RowKeyData);
	If Parameters.CheckGoodsIssue And ValueIsFilled(RowKeyData.GoodsIssue) Then
		SearchFilter.SerialNumber = EmptySerialNumber;
		SearchFilter.StructuralUnit = EmptyStructuralUnit;
		SearchFilter[Parameters.CellFieldName] = EmptyCell;
	Else
		SearchFilter.GoodsIssue = EmptyGoodsIssue;
		SearchFilter.Order = EmptyOrder;
		If Not RowKeyData.Property("SerialNumber") Then
			SearchFilter.SerialNumber = EmptySerialNumber;
		EndIf;
	EndIf;
	
	For Each KeyValue In SearchFilter Do
		If KeyValue.Value = Undefined Then
			SearchFilter.Delete(KeyValue.Key);
		EndIf;
	EndDo;
	
	BalancesRows = Parameters.Table_Balances.FindRows(SearchFilter);
	
	If BalancesRows.Count() > 0 Then
		Return BalancesRows[0].Quantity;
	Else
		Return 0;
	EndIf;
	
EndFunction

#EndRegion

#Region Private

Function DocumentParameters(DocObject)
	
	DocManager = Common.ObjectManagerByRef(DocObject.Ref);
	
	IncomingParameters = DocManager.InventoryOwnershipParameters(DocObject);
	
	If TypeOf(IncomingParameters) = Type("Array") Then
		ParametersSet = IncomingParameters;
	Else
		ParametersSet = New Array;
		ParametersSet.Add(IncomingParameters);
	EndIf;
	
	DocMetadata = DocObject.Metadata();
	
	For Each Parameters In ParametersSet Do 
		
		Parameters.Insert("DocMetadata", DocMetadata);
		
		If Not Parameters.Property("TableName") Then
			Parameters.Insert("TableName", "Inventory");
		EndIf;
		If Not Parameters.Property("OwnershipTableName") Then
			Parameters.Insert("OwnershipTableName", "InventoryOwnership");
		EndIf;
		If Not Parameters.Property("SerialNumbersTableName") Then
			Parameters.Insert("SerialNumbersTableName", "SerialNumbers");
		EndIf;
		If Not Parameters.Property("ConnectionKeyFieldName") Then
			Parameters.Insert("ConnectionKeyFieldName", "ConnectionKey");
		EndIf;
		If Not Parameters.Property("CellFieldName") Then
			Parameters.Insert("CellFieldName", "Cell");
		EndIf;
		If Not Parameters.Property("CheckGoodsIssue") Then
			Parameters.Insert("CheckGoodsIssue", False);
		EndIf;
		If Not Parameters.Property("FieldsToSkip") Then
			Parameters.Insert("FieldsToSkip", GetFieldsToSkip());
		EndIf;
		
	EndDo;
	
	Return ParametersSet;
	
EndFunction

Procedure AddKeyFields(Parameters, DocObject)
	
	DocMetaTabularSections = Parameters.DocMetadata.TabularSections;
	
	KeyFields = New Array;
	
	For Each Attribute In DocMetaTabularSections[Parameters.OwnershipTableName].Attributes Do
		
		AttributeName = Attribute.Name;
		
		If Parameters.AmountFields.Find(AttributeName) = Undefined
			And Parameters.FieldsToSkip.Find(AttributeName) = Undefined Then
			
			KeyFields.Add(AttributeName);
		EndIf;
		
	EndDo;
	
	If KeyFields.Find("GoodsIssue") = Undefined And Not Parameters.HeaderFields.Property("GoodsIssue") Then
		Parameters.HeaderFields.Insert("GoodsIssue", Documents.GoodsIssue.EmptyRef());
	EndIf;
	If KeyFields.Find("Order") = Undefined And Not Parameters.HeaderFields.Property("Order") Then
		Parameters.HeaderFields.Insert("Order", Documents.SalesOrder.EmptyRef());
	EndIf;
	
	Parameters.Insert("KeyFields", KeyFields);
	
EndProcedure

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
	|			OR FALSE)";
	
	Query.SetParameter("Ref", DocObject.Ref);
	Query.SetParameter("Date", DocObject.Date);
	IgnoreDateChange = False;
	If TypeOf(DocObject) = Type("DocumentObject.SalesSlip")
		Or TypeOf(DocObject) = Type("DocumentObject.ProductReturn")
		Or TypeOf(DocObject) = Type("DocumentObject.ShiftClosure") Then
		IgnoreDateChange = True;
	EndIf;
	Query.SetParameter("IgnoreDateChange", IgnoreDateChange);
	For Each HeaderField In Parameters.HeaderFields Do
		If ValueIsFilled(HeaderField.Value) And TypeOf(HeaderField.Value) = Type("String") Then
			Query.SetParameter(HeaderField.Key, DocObject[HeaderField.Value]);
		EndIf;
	EndDo;
	Query.Text = StrReplace(Query.Text, "&DocumentTable", Parameters.DocMetadata.FullName());
	ReplaceWithRealFieldNames(Query, Parameters);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Procedure GetDocumentTables(Parameters, DocObject)
	
	Query = New Query;
	Query.TempTablesManager = Parameters.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	InventoryDocTable._KeyFields AS _KeyFields,
	|	InventoryDocTable._AmountFields AS _AmountFields,
	|	InventoryDocTable._ConnectionKey AS _ConnectionKey,
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
	|	TT_InventoryAsIs_Initial._AmountFields AS _AmountFields,
	|	TT_InventoryAsIs_Initial._ConnectionKey AS _ConnectionKey,
	|	TT_InventoryAsIs_Initial.Quantity AS Quantity
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
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SerialNumbers.ConnectionKey AS ConnectionKey,
	|	SerialNumbers.SerialNumber AS SerialNumber
	|INTO TT_SerialNumbers
	|FROM
	|	&SerialNumbers AS SerialNumbers
	|WHERE
	|	&UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryOwnership._KeyFields AS _KeyFields,
	|	InventoryOwnership._AmountFields AS _AmountFields,
	|	InventoryOwnership.Ownership AS Ownership,
	|	InventoryOwnership.SerialNumber AS SerialNumber,
	|	InventoryOwnership.Quantity AS Quantity
	|INTO TT_OwnershipAsIs
	|FROM
	|	&InventoryOwnership AS InventoryOwnership
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryAsIs.AuxiliaryGroupingField AS AuxiliaryGroupingField,
	|	TT_InventoryAsIs._KeyFields AS _KeyFields,
	|	SUM(TT_InventoryAsIs._AmountFields) AS _AmountFields,
	|	SUM(TT_InventoryAsIs.Quantity * ISNULL(UOM.Factor, 1)) AS Quantity
	|INTO TT_InventoryGrouped
	|FROM
	|	TT_InventoryAsIs AS TT_InventoryAsIs
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TT_InventoryAsIs.MeasurementUnit = UOM.Ref
	|
	|GROUP BY
	|	TT_InventoryAsIs._KeyFields,
	|	TT_InventoryAsIs.AuxiliaryGroupingField
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryGrouped._KeyFields AS _KeyFields,
	|	ISNULL(TT_SerialNumbers.SerialNumber, VALUE(Catalog.SerialNumbers.EmptyRef)) AS SerialNumber,
	|	TT_InventoryGrouped._AmountFields AS _AmountFields,
	|	TT_InventoryGrouped.Quantity AS Quantity
	|INTO TT_Inventory
	|FROM
	|	TT_InventoryGrouped AS TT_InventoryGrouped
	|		LEFT JOIN TT_InventoryAsIs AS TT_InventoryAsIs
	|			INNER JOIN TT_SerialNumbers AS TT_SerialNumbers
	|			ON TT_InventoryAsIs._ConnectionKey = TT_SerialNumbers.ConnectionKey
	|				AND &GoodsIssueCondition
	|		ON (TRUE)
	|			AND TT_InventoryGrouped._KeyFields = TT_InventoryAsIs._KeyFields
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_OwnershipAsIs._KeyFields AS _KeyFields,
	|	TT_OwnershipAsIs._AmountFields AS _AmountFields,
	|	TT_OwnershipAsIs.Ownership AS Ownership,
	|	TT_OwnershipAsIs.SerialNumber AS SerialNumber,
	|	TT_OwnershipAsIs.Quantity AS Quantity
	|INTO TT_Ownership
	|FROM
	|	TT_OwnershipAsIs AS TT_OwnershipAsIs
	|		INNER JOIN TT_Inventory AS TT_Inventory
	|		ON (TRUE)
	|			AND TT_OwnershipAsIs._KeyFields = TT_Inventory._KeyFields
	|			AND TT_OwnershipAsIs.SerialNumber = TT_Inventory.SerialNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TRUE AS AuxiliaryGroupingField,
	|	TT_InventoryGrouped._KeyFields AS _KeyFields,
	|	TT_InventoryGrouped._AmountFields AS _AmountFields,
	|	TT_InventoryGrouped.Quantity AS Quantity
	|INTO TT_Union
	|FROM
	|	TT_InventoryGrouped AS TT_InventoryGrouped
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE,
	|	TT_Ownership._KeyFields,
	|	-TT_Ownership._AmountFields,
	|	-TT_Ownership.Quantity
	|FROM
	|	TT_Ownership AS TT_Ownership
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Union._KeyFields AS _KeyFields,
	|	SUM(TT_Union._AmountFields) AS _AmountFields,
	|	SUM(TT_Union.Quantity) AS Quantity
	|INTO TT_UnionGrouped
	|FROM
	|	TT_Union AS TT_Union
	|GROUP BY
	|	TT_Union._KeyFields,
	|	TT_Union.AuxiliaryGroupingField
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&_HeaderFields AS _HeaderFields,
	|	TT_Ownership._KeyFields AS _KeyFields,
	|	TT_Ownership._AmountFields AS _AmountFields,
	|	TT_Ownership.Ownership AS Ownership,
	|	TT_Ownership.SerialNumber AS SerialNumber,
	|	TT_Ownership.Quantity AS Quantity
	|INTO TT_AlreadyFilled
	|FROM
	|	TT_Ownership AS TT_Ownership
	|		INNER JOIN TT_UnionGrouped AS TT_UnionGrouped
	|		ON (TRUE)
	|			AND TT_Ownership._KeyFields = TT_UnionGrouped._KeyFields
	|WHERE
	|	TT_UnionGrouped.Quantity >= 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&_HeaderFields AS _HeaderFields,
	|	TT_Inventory._KeyFields AS _KeyFields,
	|	TT_Inventory.SerialNumber AS SerialNumber,
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
	|			AND TT_Inventory._KeyFields = TT_UnionGrouped._KeyFields
	|		LEFT JOIN TT_AlreadyFilled AS TT_AlreadyFilled
	|		ON TT_Inventory.SerialNumber = TT_AlreadyFilled.SerialNumber
	|			AND (TT_AlreadyFilled.SerialNumber <> VALUE(Catalog.SerialNumbers.EmptyRef))
	|WHERE
	|	TT_UnionGrouped.Quantity <> 0
	|	AND TT_AlreadyFilled.SerialNumber IS NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_Inventory._KeyFields AS _KeyFields,
	|	TT_Inventory._AmountFields AS _AmountFields,
	|	TT_Inventory.Quantity AS Quantity
	|INTO TT_ToBeAllocated
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_UnionGrouped AS TT_UnionGrouped
	|		ON TRUE
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
	|	TT_AlreadyFilled.Ownership AS Ownership,
	|	TT_AlreadyFilled.SerialNumber AS SerialNumber,
	|	TT_AlreadyFilled.Quantity AS Quantity
	|FROM
	|	TT_AlreadyFilled AS TT_AlreadyFilled
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&_HeaderFields AS _HeaderFields,
	|	TT_ToBeFilled._KeyFields AS _KeyFields,
	|	TT_ToBeFilled.SerialNumber AS SerialNumber,
	|	TT_ToBeFilled.Quantity AS Quantity
	|FROM
	|	TT_ToBeFilled AS TT_ToBeFilled
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ToBeAllocated._KeyFields AS _KeyFields,
	|	TT_ToBeAllocated._AmountFields AS _AmountFields,
	|	TT_ToBeAllocated.Quantity AS Quantity
	|FROM
	|	TT_ToBeAllocated AS TT_ToBeAllocated";
	
	Query.SetParameter("Inventory", DocObject[Parameters.TableName]);
	Query.SetParameter("SerialNumbers", DocObject[Parameters.SerialNumbersTableName]);
	Query.SetParameter("InventoryOwnership", DocObject[Parameters.OwnershipTableName]);
	Query.SetParameter("UseSerialNumbers", Parameters.UseSerialNumbers);
	For Each HeaderField In Parameters.HeaderFields Do
		If ValueIsFilled(HeaderField.Value) And TypeOf(HeaderField.Value) = Type("String") Then
			Query.SetParameter(HeaderField.Key, DocObject[HeaderField.Value]);
		Else
			Query.SetParameter(HeaderField.Key, HeaderField.Value);
		EndIf;
	EndDo;
	If Parameters.CheckGoodsIssue And Parameters.KeyFields.Find("GoodsIssue") <> Undefined Then
		Query.Text = StrReplace(Query.Text, "&GoodsIssueCondition",
			"TT_InventoryAsIs.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)");
	Else
		Query.SetParameter("GoodsIssueCondition", True);
	EndIf;
	
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
				If KeyField = "Batch"
					And CurrentLine = "	TT_InventoryAsIs_Initial._KeyFields AS _KeyFields," Then
					NewQueryLines.Add("
					|	CASE
					|		WHEN ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
					|				OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO)
					|			THEN TT_InventoryAsIs_Initial.Batch
					|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
					|	END AS Batch,");
				ElsIf KeyField = "BatchCorr"
					And CurrentLine = "	InventoryDocTable._KeyFields AS _KeyFields," Then
					NewQueryLines.Add("	InventoryDocTable.Batch AS BatchCorr,");
				Else
					NewQueryLines.Add(StrReplace(CurrentLine, "_KeyFields", KeyField));
					#Region InfobaseUpdate
					// Used in InfobaseUpdate_FillOwnershipTable update handler when updating from versions earlier than 1.3.5
					If Parameters.Property("InfobaseUpdate")
						And KeyField = "Batch"
						And CurrentLine = "	TT_ToBeFilled._KeyFields AS _KeyFields," Then
						NewQueryLines.Add("	TT_ToBeFilled.Batch.DeleteStatus AS _BatchStatus,");
						NewQueryLines.Add("	TT_ToBeFilled.Batch.DeleteBatchOwner AS _BatchCounterparty,");
					EndIf;
					#EndRegion
				EndIf;
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
			
		ElsIf StrFind(CurrentLine, "_ConnectionKey") > 0 Then
			
			NewQueryLines.Add(StrReplace(CurrentLine, "_ConnectionKey", Parameters.ConnectionKeyFieldName));
			
		Else
			
			NewQueryLines.Add(CurrentLine);
			
		EndIf;
		
	EndDo;
	
	Query.Text = StrConcat(NewQueryLines, Chars.LF);
	
EndProcedure

Procedure GetBalancesTable(Parameters, DocObject)
	
	Query = New Query;
	Query.TempTablesManager = Parameters.TempTablesManager;
	
	If TransactionActive() Then
		LockRegisterSerialNumbers(Query, Parameters);
		LockRegisterInventoryInWarehouses(Query, Parameters);
	EndIf;
	
	InverseDispatchingOrder = False;
	
	If TypeOf(DocObject) = Type("DocumentObject.ProductReturn") Then
		
		Query.Text = BalancesTableProductReturnQueryText();
		Query.SetParameter("SalesSlip", DocObject.SalesSlip);
		InverseDispatchingOrder = True;
		
	ElsIf TypeOf(DocObject) = Type("DocumentObject.ShiftClosure")
		And DocObject.CashCRSessionStatus <> Enums.ShiftClosureStatus.ClosedReceiptsArchived Then
		
		Query.Text = BalancesTableShiftClosureQueryText();
		
	ElsIf TypeOf(DocObject) = Type("DocumentObject.SalesInvoice") Then
		
		Query.SetParameter("Counterparty", DocObject.Counterparty);
		Query.SetParameter("Contract", DocObject.Contract);
		
		If TransactionActive() Then
			LockRegisterGoodsShippedNotInvoiced(Query);
		EndIf;
		
		Query.Text = BalancesTableCommonQueryText()
			+ BalancesTableGoodsShippedNotInvoicedQueryText();
		
	Else
		
		Query.Text = BalancesTableCommonQueryText();
		
	EndIf;
	
	Query.Text = Query.Text + "
	|
	|UNION ALL
	|";
	
	Query.Text = Query.Text +
	"SELECT
	|	TT_AlreadyFilled.Company,
	|	TT_AlreadyFilled.Products,
	|	TT_AlreadyFilled.Characteristic,
	|	TT_AlreadyFilled.Batch,
	|	TT_AlreadyFilled.Ownership,
	|	TT_AlreadyFilled.SerialNumber,
	|	TT_AlreadyFilled.StructuralUnit,
	|	TT_AlreadyFilled._Cell,
	|	TT_AlreadyFilled.GoodsIssue,
	|	TT_AlreadyFilled.Order,
	|	-TT_AlreadyFilled.Quantity
	|FROM
	|	TT_AlreadyFilled AS TT_AlreadyFilled
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_BalancesUngrouped.Company AS Company,
	|	TT_BalancesUngrouped.Products AS Products,
	|	TT_BalancesUngrouped.Characteristic AS Characteristic,
	|	TT_BalancesUngrouped.Batch AS Batch,
	|	TT_BalancesUngrouped.Ownership AS Ownership,
	|	TT_BalancesUngrouped.SerialNumber AS SerialNumber,
	|	TT_BalancesUngrouped.StructuralUnit AS StructuralUnit,
	|	TT_BalancesUngrouped._Cell AS _Cell,
	|	TT_BalancesUngrouped.GoodsIssue AS GoodsIssue,
	|	TT_BalancesUngrouped.Order AS Order,
	|	SUM(TT_BalancesUngrouped.Quantity) AS Quantity
	|INTO TT_Balances
	|FROM
	|	TT_BalancesUngrouped AS TT_BalancesUngrouped
	|
	|GROUP BY
	|	TT_BalancesUngrouped.Ownership,
	|	TT_BalancesUngrouped.Batch,
	|	TT_BalancesUngrouped.StructuralUnit,
	|	TT_BalancesUngrouped._Cell,
	|	TT_BalancesUngrouped.GoodsIssue,
	|	TT_BalancesUngrouped.Order,
	|	TT_BalancesUngrouped.SerialNumber,
	|	TT_BalancesUngrouped.Products,
	|	TT_BalancesUngrouped.Company,
	|	TT_BalancesUngrouped.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Balances.Company AS Company,
	|	TT_Balances.Products AS Products,
	|	TT_Balances.Characteristic AS Characteristic,
	|	TT_Balances.Batch AS Batch,
	|	TT_Balances.Ownership AS Ownership,
	|	TT_Balances.SerialNumber AS SerialNumber,
	|	TT_Balances.StructuralUnit AS StructuralUnit,
	|	TT_Balances._Cell AS _Cell,
	|	TT_Balances.GoodsIssue AS GoodsIssue,
	|	TT_Balances.Order AS Order,
	|	TT_Balances.Quantity AS Quantity,
	|	CASE
	|		WHEN ISNULL(InventoryOwnership.OwnershipType, VALUE(Enum.InventoryOwnershipTypes.OwnInventory)) = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN CASE
	|					WHEN ISNULL(AccountingPolicySliceLast.InventoryDispatchingStrategy, VALUE(Enum.InventoryDispatchingStrategy.DispatchOwnInventoryFirst)) = VALUE(Enum.InventoryDispatchingStrategy.DispatchThirdPartyInventoryFirst)
	|						THEN 0
	|					ELSE &PlusMinusOne
	|				END
	|		ELSE CASE
	|				WHEN ISNULL(AccountingPolicySliceLast.InventoryDispatchingStrategy, VALUE(Enum.InventoryDispatchingStrategy.DispatchOwnInventoryFirst)) = VALUE(Enum.InventoryDispatchingStrategy.DispatchThirdPartyInventoryFirst)
	|					THEN &PlusMinusOne
	|				ELSE 0
	|			END
	|	END AS SortingOrder
	|FROM
	|	TT_Balances AS TT_Balances
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, ) AS AccountingPolicySliceLast
	|		ON TT_Balances.Company = AccountingPolicySliceLast.Company
	|		LEFT JOIN Catalog.InventoryOwnership AS InventoryOwnership
	|		ON TT_Balances.Ownership = InventoryOwnership.Ref
	|WHERE
	|	&OwnershipType
	|
	|ORDER BY
	|	SortingOrder";
	
	Query.Text = StrReplace(Query.Text, "_Cell", Parameters.CellFieldName);
	
	Query.SetParameter("Ref", DocObject.Ref);
	Query.SetParameter("Date", DocObject.Date);
	Query.SetParameter("PlusMinusOne", 1 - 2 * Number(InverseDispatchingOrder));
	Query.SetParameter("CheckGoodsIssue", Parameters.CheckGoodsIssue);
	
	If Parameters.Property("OwnershipType") Then
		Query.Text = StrReplace(Query.Text,"&OwnershipType","InventoryOwnership.OwnershipType = &OwnershipType");
		Query.SetParameter("OwnershipType", Parameters.OwnershipType);
	Else
		Query.SetParameter("OwnershipType", True);
	EndIf;
	
	Parameters.Insert("Table_Balances", Query.Execute().Unload());
	
EndProcedure

Function BalancesTableCommonQueryText()
	
	Return
	"SELECT
	|	SerialNumbersBalance.Company AS Company,
	|	SerialNumbersBalance.Products AS Products,
	|	SerialNumbersBalance.Characteristic AS Characteristic,
	|	SerialNumbersBalance.Batch AS Batch,
	|	SerialNumbersBalance.Ownership AS Ownership,
	|	SerialNumbersBalance.SerialNumber AS SerialNumber,
	|	SerialNumbersBalance.StructuralUnit AS StructuralUnit,
	|	SerialNumbersBalance.Cell AS _Cell,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
	|	SerialNumbersBalance.QuantityBalance AS Quantity
	|INTO TT_BalancesUngrouped
	|FROM
	|	AccumulationRegister.SerialNumbers.Balance(
	|			,
	|			(Company, Products, Characteristic, Batch, SerialNumber, StructuralUnit, Cell) IN
	|				(SELECT
	|					TT_ToBeFilled.Company AS Company,
	|					TT_ToBeFilled.Products AS Products,
	|					TT_ToBeFilled.Characteristic AS Characteristic,
	|					TT_ToBeFilled.Batch AS Batch,
	|					TT_ToBeFilled.SerialNumber AS SerialNumber,
	|					TT_ToBeFilled.StructuralUnit AS StructuralUnit,
	|					TT_ToBeFilled._Cell AS Cell
	|				FROM
	|					TT_ToBeFilled AS TT_ToBeFilled
	|				WHERE
	|					TT_ToBeFilled.SerialNumber <> VALUE(Catalog.SerialNumbers.EmptyRef)
	|					AND (NOT &CheckGoodsIssue
	|						OR TT_ToBeFilled.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)))) AS SerialNumbersBalance
	|
	|UNION ALL
	|
	|SELECT
	|	InventoryInWarehousesBalance.Company,
	|	InventoryInWarehousesBalance.Products,
	|	InventoryInWarehousesBalance.Characteristic,
	|	InventoryInWarehousesBalance.Batch,
	|	InventoryInWarehousesBalance.Ownership,
	|	VALUE(Catalog.SerialNumbers.EmptyRef),
	|	InventoryInWarehousesBalance.StructuralUnit,
	|	InventoryInWarehousesBalance.Cell,
	|	VALUE(Document.GoodsIssue.EmptyRef),
	|	VALUE(Document.SalesOrder.EmptyRef),
	|	InventoryInWarehousesBalance.QuantityBalance
	|FROM
	|	AccumulationRegister.InventoryInWarehouses.Balance(
	|			,
	|			(Company, Products, Characteristic, Batch, StructuralUnit, Cell) IN
	|				(SELECT
	|					TT_ToBeFilled.Company AS Company,
	|					TT_ToBeFilled.Products AS Products,
	|					TT_ToBeFilled.Characteristic AS Characteristic,
	|					TT_ToBeFilled.Batch AS Batch,
	|					TT_ToBeFilled.StructuralUnit AS StructuralUnit,
	|					TT_ToBeFilled._Cell AS Cell
	|				FROM
	|					TT_ToBeFilled AS TT_ToBeFilled
	|				WHERE
	|					TT_ToBeFilled.SerialNumber = VALUE(Catalog.SerialNumbers.EmptyRef)
	|					AND (NOT &CheckGoodsIssue
	|						OR TT_ToBeFilled.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)))) AS InventoryInWarehousesBalance
	|
	|UNION ALL
	|
	|SELECT
	|	SerialNumbers.Company,
	|	SerialNumbers.Products,
	|	SerialNumbers.Characteristic,
	|	SerialNumbers.Batch,
	|	SerialNumbers.Ownership,
	|	SerialNumbers.SerialNumber,
	|	SerialNumbers.StructuralUnit,
	|	SerialNumbers.Cell,
	|	VALUE(Document.GoodsIssue.EmptyRef),
	|	VALUE(Document.SalesOrder.EmptyRef),
	|	CASE
	|		WHEN SerialNumbers.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN SerialNumbers.Quantity
	|		ELSE -SerialNumbers.Quantity
	|	END
	|FROM
	|	AccumulationRegister.SerialNumbers AS SerialNumbers
	|WHERE
	|	SerialNumbers.Recorder = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	InventoryInWarehouses.Company,
	|	InventoryInWarehouses.Products,
	|	InventoryInWarehouses.Characteristic,
	|	InventoryInWarehouses.Batch,
	|	InventoryInWarehouses.Ownership,
	|	VALUE(Catalog.SerialNumbers.EmptyRef),
	|	InventoryInWarehouses.StructuralUnit,
	|	InventoryInWarehouses.Cell,
	|	VALUE(Document.GoodsIssue.EmptyRef),
	|	VALUE(Document.SalesOrder.EmptyRef),
	|	CASE
	|		WHEN InventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN InventoryInWarehouses.Quantity
	|		ELSE -InventoryInWarehouses.Quantity
	|	END
	|FROM
	|	AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
	|WHERE
	|	InventoryInWarehouses.Recorder = &Ref";
	
EndFunction

Function BalancesTableGoodsShippedNotInvoicedQueryText()
	
	QueryText = "
	|
	|UNION ALL
	|";
	
	QueryText = QueryText +
	"SELECT
	|	GoodsShippedNotInvoicedBalance.Company AS Company,
	|	GoodsShippedNotInvoicedBalance.Products AS Products,
	|	GoodsShippedNotInvoicedBalance.Characteristic AS Characteristic,
	|	GoodsShippedNotInvoicedBalance.Batch AS Batch,
	|	GoodsShippedNotInvoicedBalance.Ownership AS Ownership,
	|	VALUE(Catalog.SerialNumbers.EmptyRef) AS SerialNumber,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS StructuralUnit,
	|	VALUE(Catalog.Cells.EmptyRef) AS Cell,
	|	GoodsShippedNotInvoicedBalance.GoodsIssue AS GoodsIssue,
	|	GoodsShippedNotInvoicedBalance.SalesOrder AS Order,
	|	GoodsShippedNotInvoicedBalance.QuantityBalance AS Quantity
	|FROM
	|	AccumulationRegister.GoodsShippedNotInvoiced.Balance(
	|			,
	|			Counterparty = &Counterparty
	|				AND Contract = &Contract
	|				AND (GoodsIssue, Company, SalesOrder, Products, Characteristic, Batch) IN
	|					(SELECT
	|						TT_ToBeFilled.GoodsIssue AS GoodsIssue,
	|						TT_ToBeFilled.Company AS Company,
	|						TT_ToBeFilled.Order AS SalesOrder,
	|						TT_ToBeFilled.Products AS Products,
	|						TT_ToBeFilled.Characteristic AS Characteristic,
	|						TT_ToBeFilled.Batch AS Batch
	|					FROM
	|						TT_ToBeFilled AS TT_ToBeFilled)) AS GoodsShippedNotInvoicedBalance
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsShippedNotInvoiced.Company,
	|	GoodsShippedNotInvoiced.Products,
	|	GoodsShippedNotInvoiced.Characteristic,
	|	GoodsShippedNotInvoiced.Batch,
	|	GoodsShippedNotInvoiced.Ownership,
	|	VALUE(Catalog.SerialNumbers.EmptyRef),
	|	VALUE(Catalog.BusinessUnits.EmptyRef),
	|	VALUE(Catalog.Cells.EmptyRef),
	|	GoodsShippedNotInvoiced.GoodsIssue,
	|	GoodsShippedNotInvoiced.SalesOrder,
	|	CASE
	|		WHEN GoodsShippedNotInvoiced.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN GoodsShippedNotInvoiced.Quantity
	|		ELSE -GoodsShippedNotInvoiced.Quantity
	|	END
	|FROM
	|	AccumulationRegister.GoodsShippedNotInvoiced AS GoodsShippedNotInvoiced
	|WHERE
	|	GoodsShippedNotInvoiced.Recorder = &Ref
	|	AND GoodsShippedNotInvoiced.Counterparty = &Counterparty
	|	AND GoodsShippedNotInvoiced.Contract = &Contract";
	
	Return QueryText;
	
EndFunction

Function BalancesTableProductReturnQueryText()
	
	QueryText = 
	"SELECT
	|	SalesSlip.Ref AS Ref
	|INTO TT_SalesSlip
	|FROM
	|	Document.SalesSlip AS SalesSlip
	|WHERE
	|	SalesSlip.Ref = &SalesSlip
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductReturn.Ref AS Ref
	|INTO TT_ProductReturn
	|FROM
	|	Document.ProductReturn AS ProductReturn
	|WHERE
	|	ProductReturn.SalesSlip = &SalesSlip
	|	AND ProductReturn.Ref <> &Ref";
	
	QueryText = QueryText + DriveClientServer.GetQueryDelimeter();
	QueryText = QueryText + BalancesTableProductReturnAndShiftClosureCommonPartQueryText();
	
	Return QueryText;
	
EndFunction

Function BalancesTableShiftClosureQueryText()
	
	QueryText =
	"SELECT
	|	SalesSlip.Ref AS Ref
	|INTO TT_SalesSlip
	|FROM
	|	Document.SalesSlip AS SalesSlip
	|WHERE
	|	SalesSlip.CashCRSession = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductReturn.Ref AS Ref
	|INTO TT_ProductReturn
	|FROM
	|	Document.ProductReturn AS ProductReturn
	|WHERE
	|	ProductReturn.CashCRSession = &Ref";
	
	QueryText = QueryText + DriveClientServer.GetQueryDelimeter();
	QueryText = QueryText + BalancesTableProductReturnAndShiftClosureCommonPartQueryText();
	
	Return QueryText;
	
EndFunction

Function BalancesTableProductReturnAndShiftClosureCommonPartQueryText()
	
	Return
	"SELECT
	|	InventoryInWarehouses.Recorder AS Recorder,
	|	InventoryInWarehouses.Company AS Company,
	|	InventoryInWarehouses.Products AS Products,
	|	InventoryInWarehouses.Characteristic AS Characteristic,
	|	InventoryInWarehouses.Batch AS Batch,
	|	InventoryInWarehouses.Ownership AS Ownership,
	|	InventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	InventoryInWarehouses.Cell AS Cell,
	|	InventoryInWarehouses.Quantity AS Quantity
	|INTO TT_InventoryInWarehousesRecords
	|FROM
	|	TT_ToBeFilled AS TT_ToBeFilled
	|		INNER JOIN AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
	|		ON TT_ToBeFilled.Company = InventoryInWarehouses.Company
	|			AND TT_ToBeFilled.Products = InventoryInWarehouses.Products
	|			AND TT_ToBeFilled.Characteristic = InventoryInWarehouses.Characteristic
	|			AND TT_ToBeFilled.Batch = InventoryInWarehouses.Batch
	|			AND TT_ToBeFilled.StructuralUnit = InventoryInWarehouses.StructuralUnit
	|			AND TT_ToBeFilled.Cell = InventoryInWarehouses.Cell
	|WHERE
	|	TT_ToBeFilled.SerialNumber = VALUE(Catalog.SerialNumbers.EmptyRef)
	|	AND InventoryInWarehouses.Active
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SerialNumbers.Recorder AS Recorder,
	|	SerialNumbers.Company AS Company,
	|	SerialNumbers.Products AS Products,
	|	SerialNumbers.Characteristic AS Characteristic,
	|	SerialNumbers.Batch AS Batch,
	|	SerialNumbers.Ownership AS Ownership,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	SerialNumbers.StructuralUnit AS StructuralUnit,
	|	SerialNumbers.Cell AS Cell,
	|	SerialNumbers.Quantity AS Quantity
	|INTO TT_SerialNumbersRecords
	|FROM
	|	TT_ToBeFilled AS TT_ToBeFilled
	|		INNER JOIN AccumulationRegister.SerialNumbers AS SerialNumbers
	|		ON TT_ToBeFilled.Company = SerialNumbers.Company
	|			AND TT_ToBeFilled.Products = SerialNumbers.Products
	|			AND TT_ToBeFilled.Characteristic = SerialNumbers.Characteristic
	|			AND TT_ToBeFilled.Batch = SerialNumbers.Batch
	|			AND TT_ToBeFilled.SerialNumber = SerialNumbers.SerialNumber
	|			AND TT_ToBeFilled.StructuralUnit = SerialNumbers.StructuralUnit
	|			AND TT_ToBeFilled.Cell = SerialNumbers.Cell
	|WHERE
	|	TT_ToBeFilled.SerialNumber <> VALUE(Catalog.SerialNumbers.EmptyRef)
	|	AND SerialNumbers.Active
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryInWarehousesRecords.Company AS Company,
	|	TT_InventoryInWarehousesRecords.Products AS Products,
	|	TT_InventoryInWarehousesRecords.Characteristic AS Characteristic,
	|	TT_InventoryInWarehousesRecords.Batch AS Batch,
	|	TT_InventoryInWarehousesRecords.Ownership AS Ownership,
	|	VALUE(Catalog.SerialNumbers.EmptyRef) AS SerialNumber,
	|	TT_InventoryInWarehousesRecords.StructuralUnit AS StructuralUnit,
	|	TT_InventoryInWarehousesRecords.Cell AS Cell,
	|	VALUE(Document.GoodsIssue.EmptyRef) AS GoodsIssue,
	|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
	|	TT_InventoryInWarehousesRecords.Quantity AS Quantity
	|INTO TT_BalancesUngrouped
	|FROM
	|	TT_SalesSlip AS TT_SalesSlip
	|		INNER JOIN TT_InventoryInWarehousesRecords AS TT_InventoryInWarehousesRecords
	|		ON TT_SalesSlip.Ref = TT_InventoryInWarehousesRecords.Recorder
	|
	|UNION ALL
	|
	|SELECT
	|	TT_InventoryInWarehousesRecords.Company,
	|	TT_InventoryInWarehousesRecords.Products,
	|	TT_InventoryInWarehousesRecords.Characteristic,
	|	TT_InventoryInWarehousesRecords.Batch,
	|	TT_InventoryInWarehousesRecords.Ownership,
	|	VALUE(Catalog.SerialNumbers.EmptyRef),
	|	TT_InventoryInWarehousesRecords.StructuralUnit,
	|	TT_InventoryInWarehousesRecords.Cell,
	|	VALUE(Document.GoodsIssue.EmptyRef),
	|	VALUE(Document.SalesOrder.EmptyRef),
	|	-TT_InventoryInWarehousesRecords.Quantity
	|FROM
	|	TT_ProductReturn AS TT_ProductReturn
	|		INNER JOIN TT_InventoryInWarehousesRecords AS TT_InventoryInWarehousesRecords
	|		ON TT_ProductReturn.Ref = TT_InventoryInWarehousesRecords.Recorder
	|
	|UNION ALL
	|
	|SELECT
	|	TT_SerialNumbersRecords.Company,
	|	TT_SerialNumbersRecords.Products,
	|	TT_SerialNumbersRecords.Characteristic,
	|	TT_SerialNumbersRecords.Batch,
	|	TT_SerialNumbersRecords.Ownership,
	|	TT_SerialNumbersRecords.SerialNumber,
	|	TT_SerialNumbersRecords.StructuralUnit,
	|	TT_SerialNumbersRecords.Cell,
	|	VALUE(Document.GoodsIssue.EmptyRef),
	|	VALUE(Document.SalesOrder.EmptyRef),
	|	TT_SerialNumbersRecords.Quantity
	|FROM
	|	TT_SalesSlip AS TT_SalesSlip
	|		INNER JOIN TT_SerialNumbersRecords AS TT_SerialNumbersRecords
	|		ON TT_SalesSlip.Ref = TT_SerialNumbersRecords.Recorder
	|
	|UNION ALL
	|
	|SELECT
	|	TT_SerialNumbersRecords.Company,
	|	TT_SerialNumbersRecords.Products,
	|	TT_SerialNumbersRecords.Characteristic,
	|	TT_SerialNumbersRecords.Batch,
	|	TT_SerialNumbersRecords.Ownership,
	|	TT_SerialNumbersRecords.SerialNumber,
	|	TT_SerialNumbersRecords.StructuralUnit,
	|	TT_SerialNumbersRecords.Cell,
	|	VALUE(Document.GoodsIssue.EmptyRef),
	|	VALUE(Document.SalesOrder.EmptyRef),
	|	-TT_SerialNumbersRecords.Quantity
	|FROM
	|	TT_ProductReturn AS TT_ProductReturn
	|		INNER JOIN TT_SerialNumbersRecords AS TT_SerialNumbersRecords
	|		ON TT_ProductReturn.Ref = TT_SerialNumbersRecords.Recorder";
	
EndFunction

Procedure LockRegisterSerialNumbers(Query, Parameters)
	
	Query.Text =
	"SELECT
	|	TT_ToBeFilled.Company AS Company,
	|	TT_ToBeFilled.Products AS Products,
	|	TT_ToBeFilled.Characteristic AS Characteristic,
	|	TT_ToBeFilled.Batch AS Batch,
	|	TT_ToBeFilled.SerialNumber AS SerialNumber,
	|	TT_ToBeFilled.StructuralUnit AS StructuralUnit,
	|	TT_ToBeFilled._Cell AS Cell
	|FROM
	|	TT_ToBeFilled AS TT_ToBeFilled
	|WHERE
	|	TT_ToBeFilled.SerialNumber <> VALUE(Catalog.SerialNumbers.EmptyRef)";
	
	Query.Text = StrReplace(Query.Text, "_Cell", Parameters.CellFieldName);
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.SerialNumbers");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
EndProcedure

Procedure LockRegisterInventoryInWarehouses(Query, Parameters)
	
	Query.Text =
	"SELECT
	|	TT_ToBeFilled.Company AS Company,
	|	TT_ToBeFilled.Products AS Products,
	|	TT_ToBeFilled.Characteristic AS Characteristic,
	|	TT_ToBeFilled.Batch AS Batch,
	|	TT_ToBeFilled.StructuralUnit AS StructuralUnit,
	|	TT_ToBeFilled._Cell AS Cell
	|FROM
	|	TT_ToBeFilled AS TT_ToBeFilled
	|WHERE
	|	TT_ToBeFilled.SerialNumber = VALUE(Catalog.SerialNumbers.EmptyRef)";
	
	Query.Text = StrReplace(Query.Text, "_Cell", Parameters.CellFieldName);
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryInWarehouses");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
EndProcedure

Procedure LockRegisterGoodsShippedNotInvoiced(Query)
	
	Query.Text =
	"SELECT DISTINCT
	|	TT_ToBeFilled.GoodsIssue AS GoodsIssue,
	|	TT_ToBeFilled.Company AS Company,
	|	&Counterparty AS Counterparty,
	|	&Contract AS Contract,
	|	ISNULL(CAST(TT_ToBeFilled.Order AS Document.SalesOrder), VALUE(Document.SalesOrder.EmptyRef)) AS SalesOrder,
	|	TT_ToBeFilled.Products AS Products,
	|	TT_ToBeFilled.Characteristic AS Characteristic,
	|	TT_ToBeFilled.Batch AS Batch
	|FROM
	|	TT_ToBeFilled AS TT_ToBeFilled
	|WHERE
	|	TT_ToBeFilled.GoodsIssue <> VALUE(Document.GoodsIssue.EmptyRef)";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.GoodsShippedNotInvoiced");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
EndProcedure

Procedure FillOwnership(Parameters)
	
	SearchFilter = New Structure(
		"Company,
		|Products,
		|Characteristic,
		|Batch,
		|SerialNumber,
		|StructuralUnit,
		|GoodsIssue,
		|Order");
	SearchFilter.Insert(Parameters.CellFieldName);
	
	EmptySerialNumber = Catalogs.SerialNumbers.EmptyRef();
	EmptyStructuralUnit = Catalogs.BusinessUnits.EmptyRef();
	EmptyCell = Catalogs.Cells.EmptyRef();
	EmptyGoodsIssue = Documents.GoodsIssue.EmptyRef();
	EmptyOrder = Documents.SalesOrder.EmptyRef();
	
	For Each ToBeFilledRow In Parameters.Table_ToBeFilled Do
		
		FillPropertyValues(SearchFilter, ToBeFilledRow);
		If Parameters.CheckGoodsIssue And ValueIsFilled(ToBeFilledRow.GoodsIssue) Then
			SearchFilter.SerialNumber = EmptySerialNumber;
			SearchFilter.StructuralUnit = EmptyStructuralUnit;
			SearchFilter[Parameters.CellFieldName] = EmptyCell;
		Else
			SearchFilter.GoodsIssue = EmptyGoodsIssue;
			SearchFilter.Order = EmptyOrder;
		EndIf;
		
		BalancesRows = Parameters.Table_Balances.FindRows(SearchFilter);
		
		If ValueIsFilled(ToBeFilledRow.SerialNumber) Then
			QuantityNeeded = 1;
		Else
			QuantityNeeded = ToBeFilledRow.Quantity;
		EndIf;
		
		For Each BalancesRow In BalancesRows Do
			
			If BalancesRow.Quantity <=0 Then
				Continue;
			EndIf;
			
			NewRow = Parameters.Table_AlreadyFilled.Add();
			FillPropertyValues(NewRow, ToBeFilledRow);
			NewRow.Ownership = BalancesRow.Ownership;
			
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
			NewRow.Ownership = DefaultOwnership(Parameters);
			NewRow.Quantity = QuantityNeeded;
			
		EndIf;
		
	EndDo;
	
	GroupingColumns = StringFunctionsClientServer.StringFromSubstringArray(Parameters.KeyFields);
	GroupingColumns = GroupingColumns + ", SerialNumber, Ownership";
	
	TotalingColumns = StringFunctionsClientServer.StringFromSubstringArray(Parameters.AmountFields);
	TotalingColumns = TotalingColumns + ", Quantity";
	
	Parameters.Table_AlreadyFilled.GroupBy(GroupingColumns, TotalingColumns);
	
EndProcedure

Function DefaultOwnership(Parameters)
	
	If Parameters.Property("DefaultOwnership") Then
		DefaultOwnership = Parameters.DefaultOwnership;
	Else
		DefaultOwnership = Catalogs.InventoryOwnership.OwnInventory();
		Parameters.Insert("DefaultOwnership", DefaultOwnership);
	EndIf;
	
	Return DefaultOwnership;
	
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

Function GetTableForOwnershipTreeFilling(Parameters, DocObject)
	
	Query = New Query;
	
	Query.TempTablesManager = Parameters.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	InventoryDocTable._KeyFields AS _KeyFields,
	|	InventoryDocTable._AmountFields AS _AmountFields,
	|	InventoryDocTable.ConnectionKey AS ConnectionKey,
	|	InventoryDocTable.Quantity AS Quantity
	|INTO TT_InventoryAsIs_Initial
	|FROM
	|	&Inventory AS InventoryDocTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryAsIs_Initial._KeyFields AS _KeyFields,
	|	TT_InventoryAsIs_Initial._AmountFields AS _AmountFields,
	|	NOT (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|		OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO)) AS _IgnoreBatch,
	|	TT_InventoryAsIs_Initial._ConnectionKey AS _ConnectionKey,
	|	TT_InventoryAsIs_Initial.Quantity AS Quantity
	|INTO TT_InventoryAsIs
	|FROM
	|	TT_InventoryAsIs_Initial AS TT_InventoryAsIs_Initial
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON TT_InventoryAsIs_Initial.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON (&StructuralUnit = BatchTrackingPolicy.StructuralUnit)
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SerialNumbers.ConnectionKey AS ConnectionKey,
	|	SerialNumbers.SerialNumber AS SerialNumber
	|INTO TT_SerialNumbers
	|FROM
	|	&SerialNumbers AS SerialNumbers
	|WHERE
	|	&UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CatalogProducts.UseSerialNumbers
	|		AND &UseSerialNumbers
	|		AND &GoodsIssueCondition AS _UseSerialNumbers,
	|	TT_InventoryAsIs._KeyFields AS _KeyFields,
	|	TT_InventoryAsIs._IgnoreBatch AS _IgnoreBatch,
	|	SUM(TT_InventoryAsIs._AmountFields) AS _AmountFields,
	|	SUM(TT_InventoryAsIs.Quantity) AS Quantity,
	|	SUM(TT_InventoryAsIs.Quantity * ISNULL(UOM.Factor, 1)) AS _BaseQuantity
	|INTO TT_Inventory
	|FROM
	|	TT_InventoryAsIs AS TT_InventoryAsIs
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON TT_InventoryAsIs.MeasurementUnit = UOM.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TT_InventoryAsIs.Products = CatalogProducts.Ref
	|
	|GROUP BY
	|	TT_InventoryAsIs._KeyFields,
	|	TT_InventoryAsIs._IgnoreBatch,
	|	CatalogProducts.UseSerialNumbers
	|		AND &UseSerialNumbers
	|		AND &GoodsIssueCondition
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&_HeaderFields AS _HeaderFields,
	|	TT_Inventory._KeyFields AS _KeyFields,
	|	VALUE(Catalog.SerialNumbers.EmptyRef) AS SerialNumber,
	|	TT_Inventory.Quantity AS Quantity
	|INTO TT_ToBeFilled
	|FROM
	|	TT_Inventory AS TT_Inventory
	|WHERE
	|	NOT TT_Inventory._UseSerialNumbers
	|
	|UNION ALL
	|
	|SELECT
	|	&_HeaderFields,
	|	TT_Inventory._KeyFields,
	|	TT_SerialNumbers.SerialNumber,
	|	1
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		LEFT JOIN TT_InventoryAsIs AS TT_InventoryAsIs
	|			INNER JOIN TT_SerialNumbers AS TT_SerialNumbers
	|			ON TT_InventoryAsIs._ConnectionKey = TT_SerialNumbers.ConnectionKey
	|				AND &GoodsIssueCondition
	|		ON (TRUE)
	|			AND TT_Inventory._KeyFields = TT_InventoryAsIs._KeyFields
	|WHERE
	|	TT_Inventory._UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 0
	|	&_HeaderFields AS _HeaderFields,
	|	TT_Inventory._KeyFields AS _KeyFields,
	|	TT_Inventory._AmountFields AS _AmountFields,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS Ownership,
	|	VALUE(Catalog.SerialNumbers.EmptyRef) AS SerialNumber,
	|	TT_Inventory.Quantity AS Quantity
	|INTO TT_AlreadyFilled
	|FROM
	|	TT_Inventory AS TT_Inventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory._UseSerialNumbers AS _UseSerialNumbers,
	|	TT_Inventory._KeyFields AS _KeyFields,
	|	TT_Inventory._IgnoreBatch AS _IgnoreBatch,
	|	TT_Inventory._AmountFields AS _AmountFields,
	|	TT_Inventory.Quantity AS Quantity,
	|	TT_Inventory._BaseQuantity AS _BaseQuantity
	|FROM
	|	TT_Inventory AS TT_Inventory";
	
	Query.SetParameter("Inventory", DocObject[Parameters.TableName]);
	Query.SetParameter("SerialNumbers", DocObject[Parameters.SerialNumbersTableName]);
	Query.SetParameter("UseSerialNumbers", Parameters.UseSerialNumbers);
	For Each HeaderField In Parameters.HeaderFields Do
		If ValueIsFilled(HeaderField.Value) And TypeOf(HeaderField.Value) = Type("String") Then
			Query.SetParameter(HeaderField.Key, DocObject[HeaderField.Value]);
		Else
			Query.SetParameter(HeaderField.Key, HeaderField.Value);
		EndIf;
	EndDo;
	If Parameters.CheckGoodsIssue And Parameters.KeyFields.Find("GoodsIssue") <> Undefined Then
		Query.Text = StrReplace(Query.Text, "&GoodsIssueCondition",
			"TT_InventoryAsIs.GoodsIssue = VALUE(Document.GoodsIssue.EmptyRef)");
	Else
		Query.SetParameter("GoodsIssueCondition", True);
	EndIf;
	
	ReplaceWithRealFieldNames(Query, Parameters);
	
	Return Query.Execute().Unload();
	
EndFunction

Function GetFieldsToSkip()
	
	FieldsToSkip = New Array;
	FieldsToSkip.Add("Quantity");
	FieldsToSkip.Add("SerialNumber");
	FieldsToSkip.Add("Ownership");
	
	Return FieldsToSkip;
	
EndFunction

#EndRegion