
#Region Public

#Region DuplicateRules

Function MatchingCriteriasForObjects(TypeOfNewObject, TypeOfExistingObject) Export
	
	MatchingCriteriasTable = MatchingCriteriasTable();
	
	Filter = New Structure();
	Filter.Insert("TypeOfNewObject", TypeOfNewObject);
	Filter.Insert("TypeOfExistingObject", TypeOfExistingObject);
	
	Return MatchingCriteriasTable.FindRows(Filter);
	
EndFunction

Function MatchingObjectsForObjects(TypeOfNewObject) Export
	
	MatchingCriteriasTable = MatchingCriteriasTable();
	
	Filter = New Structure();
	Filter.Insert("TypeOfNewObject", TypeOfNewObject);
	
	Rows = MatchingCriteriasTable.FindRows(Filter);
	
	ArrayOfObjects = New Array;
	
	For Each Row In Rows Do
		
		If ArrayOfObjects.Find(Row.TypeOfExistingObject) = Undefined Then
			
			ArrayOfObjects.Add(Row.TypeOfExistingObject);
			
		EndIf;
		
	EndDo;
	
	Return ArrayOfObjects;
	
EndFunction

#EndRegion

#Region DuplicateRulesIndex

Procedure PrepareDuplicateRulesIndexTable(ObjectRef, AdditionalProperties) Export
	
	Query = New Query;
	QueryText = "";
	
	ObjectType = TypeOf(ObjectRef);
	
	If ObjectType = Type("CatalogRef.Counterparties") Then
		
		#Region CounterpartiesQueryText
		
		QueryText =
		"SELECT ALLOWED
		|	Counterparties.Ref AS Ref,
		|	Counterparties.Description AS Description,
		|	Counterparties.DescriptionFull AS DescriptionFull,
		|	Counterparties.VATNumber AS VATNumber,
		|	Counterparties.RegistrationNumber AS RegistrationNumber
		|INTO CounterpartiesTable
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.Ref = &Ref
		|	AND NOT Counterparties.DeletionMark
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	CounterpartiesContactInformation.Presentation AS Value,
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties) AS ObjectType,
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation) AS ObjectCriteria,
		|	CounterpartiesContactInformation.Type AS Type,
		|	CounterpartiesContactInformation.Ref AS ObjectRef,
		|	CounterpartiesContactInformation.Kind AS Kind,
		|	CounterpartiesContactInformation.Ref AS Counterparty,
		|	CounterpartiesContactInformation.Presentation AS Presentation
		|FROM
		|	CounterpartiesTable AS CounterpartiesTable
		|		INNER JOIN Catalog.Counterparties.ContactInformation AS CounterpartiesContactInformation
		|		ON CounterpartiesTable.Ref = CounterpartiesContactInformation.Ref
		|
		|UNION ALL
		|
		|SELECT
		|	CounterpartiesTable.Description,
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description),
		|	NULL,
		|	CounterpartiesTable.Ref,
		|	NULL,
		|	CounterpartiesTable.Ref,
		|	CounterpartiesTable.Description
		|FROM
		|	CounterpartiesTable AS CounterpartiesTable
		|
		|UNION ALL
		|
		|SELECT
		|	CounterpartiesTable.DescriptionFull,
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsCriterias.DescriptionFull),
		|	NULL,
		|	CounterpartiesTable.Ref,
		|	NULL,
		|	CounterpartiesTable.Ref,
		|	CounterpartiesTable.DescriptionFull
		|FROM
		|	CounterpartiesTable AS CounterpartiesTable
		|
		|UNION ALL
		|
		|SELECT
		|	CounterpartiesTable.VATNumber,
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsCriterias.VATNumber),
		|	NULL,
		|	CounterpartiesTable.Ref,
		|	NULL,
		|	CounterpartiesTable.Ref,
		|	CounterpartiesTable.VATNumber
		|FROM
		|	CounterpartiesTable AS CounterpartiesTable
		|
		|UNION ALL
		|
		|SELECT
		|	CounterpartiesTable.RegistrationNumber,
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsCriterias.RegistrationNumber),
		|	NULL,
		|	CounterpartiesTable.Ref,
		|	NULL,
		|	CounterpartiesTable.Ref,
		|	CounterpartiesTable.RegistrationNumber
		|FROM
		|	CounterpartiesTable AS CounterpartiesTable";
		
		#EndRegion
		
	ElsIf ObjectType = Type("CatalogRef.ContactPersons") Then
		
		#Region ContactPersonsQueryText
		
		QueryText =
		"SELECT ALLOWED
		|	ContactPersons.Ref AS Ref,
		|	ContactPersons.Description AS Description,
		|	ContactPersons.Owner AS Counterparty
		|INTO ContactPersonsTable
		|FROM
		|	Catalog.ContactPersons AS ContactPersons
		|WHERE
		|	ContactPersons.Ref = &Ref
		|	AND NOT ContactPersons.DeletionMark
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	ContactPersonsContactInformation.Presentation AS Value,
		|	VALUE(Enum.DuplicateObjectsTypes.ContactPersons) AS ObjectType,
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation) AS ObjectCriteria,
		|	ContactPersonsContactInformation.Type AS Type,
		|	ContactPersonsContactInformation.Ref AS ObjectRef,
		|	ContactPersonsContactInformation.Kind AS Kind,
		|	ContactPersonsTable.Counterparty AS Counterparty,
		|	ContactPersonsContactInformation.Presentation AS Presentation
		|FROM
		|	ContactPersonsTable AS ContactPersonsTable
		|		INNER JOIN Catalog.ContactPersons.ContactInformation AS ContactPersonsContactInformation
		|		ON ContactPersonsTable.Ref = ContactPersonsContactInformation.Ref
		|
		|UNION ALL
		|
		|SELECT
		|	ContactPersonsTable.Description,
		|	VALUE(Enum.DuplicateObjectsTypes.ContactPersons),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description),
		|	NULL,
		|	ContactPersonsTable.Ref,
		|	NULL,
		|	ContactPersonsTable.Counterparty,
		|	ContactPersonsTable.Description
		|FROM
		|	ContactPersonsTable AS ContactPersonsTable";
		
		#EndRegion
		
	ElsIf ObjectType = Type("CatalogRef.Leads") Then
		
		#Region LeadsQueryText
		
		QueryText =
		"SELECT ALLOWED
		|	Leads.Ref AS Ref,
		|	Leads.Description AS Description,
		|	Leads.Counterparty AS Counterparty
		|INTO LeadsTable
		|FROM
		|	Catalog.Leads AS Leads
		|WHERE
		|	Leads.Ref = &Ref
		|	AND NOT Leads.DeletionMark
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	LeadsContactInformation.Presentation AS Value,
		|	VALUE(Enum.DuplicateObjectsTypes.Leads) AS ObjectType,
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation) AS ObjectCriteria,
		|	LeadsContactInformation.Type AS Type,
		|	LeadsContactInformation.Ref AS ObjectRef,
		|	LeadsContactInformation.Kind AS Kind,
		|	LeadsTable.Counterparty AS Counterparty,
		|	LeadsContactInformation.Presentation AS Presentation
		|FROM
		|	LeadsTable AS LeadsTable
		|		INNER JOIN Catalog.Leads.ContactInformation AS LeadsContactInformation
		|		ON LeadsTable.Ref = LeadsContactInformation.Ref
		|
		|UNION ALL
		|
		|SELECT
		|	LeadsTable.Description,
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description),
		|	NULL,
		|	LeadsTable.Ref,
		|	NULL,
		|	LeadsTable.Counterparty,
		|	LeadsTable.Description
		|FROM
		|	LeadsTable AS LeadsTable";
		
		#EndRegion
		
	ElsIf ObjectType = Type("CatalogRef.Products") Then
		
		#Region ProductsText
		
		QueryText =
		"SELECT
		|	Products.Ref AS Ref,
		|	Products.Description AS Description,
		|	Products.SKU AS SKU,
		|	Products.DescriptionFull AS DescriptionFull
		|INTO ProductsTable
		|FROM
		|	Catalog.Products AS Products
		|WHERE
		|	Products.Ref = &Ref
		|	AND NOT Products.DeletionMark
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ProductsTable.Description AS Value,
		|	VALUE(Enum.DuplicateObjectsTypes.Products) AS ObjectType,
		|	VALUE(Enum.DuplicateObjectsCriterias.Description) AS ObjectCriteria,
		|	ProductsTable.Ref AS ObjectRef,
		|	ProductsTable.Description AS Presentation
		|FROM
		|	ProductsTable AS ProductsTable
		|
		|UNION ALL
		|
		|SELECT
		|	ProductsTable.SKU,
		|	VALUE(Enum.DuplicateObjectsTypes.Products),
		|	VALUE(Enum.DuplicateObjectsCriterias.SKU),
		|	ProductsTable.Ref,
		|	ProductsTable.SKU
		|FROM
		|	ProductsTable AS ProductsTable
		|
		|UNION ALL
		|
		|SELECT
		|	ProductsTable.DescriptionFull,
		|	VALUE(Enum.DuplicateObjectsTypes.Products),
		|	VALUE(Enum.DuplicateObjectsCriterias.DescriptionFull),
		|	ProductsTable.Ref,
		|	ProductsTable.DescriptionFull
		|FROM
		|	ProductsTable AS ProductsTable";
		
		#EndRegion
		
	EndIf;
	
	DuplicateRulesIndexTable =
		InformationRegisters.DuplicateRulesIndex.CreateRecordSet().UnloadColumns();
	
	If ValueIsFilled(QueryText) Then
		
		Query.Text = QueryText;
		Query.SetParameter("Ref", ObjectRef);
		QueryResult = Query.Execute();
		SelectionDetailRecords = QueryResult.Select();
		
		While SelectionDetailRecords.Next() Do
			
			If ValueIsFilled(SelectionDetailRecords.Value) Then
				
				NewLine = DuplicateRulesIndexTable.Add();
				
				FillPropertyValues(NewLine, SelectionDetailRecords);
				
				DataHashing = New DataHashing(HashFunction.SHA256);
				DataHashing.Append(SelectionDetailRecords.Value);
				NewLine.HashSum = Base64String(DataHashing.HashSum);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	AdditionalProperties.Insert("DuplicateRulesIndexTable", DuplicateRulesIndexTable);

EndProcedure

// Function checks object duplicates in object form
//
// Parameters:
// ObjectParameters - Structure - Structure with form attributes, created by "DriveClient.GetDuplicateCheckingParameters"
//
// Returns:
//	Structure - contains two elements:
//		* DuplicatesTableAddress			- String - address of table with founded duplicates.
//		* DuplicateRulesIndexTableAddress	- String - address of table with attributes of current object.
Function DuplicatesTableStructure(ObjectParameters) Export
	
	DuplicatesTableStructure = New Structure();
	DuplicatesTableStructure.Insert("DuplicatesTableAddress", "");
	DuplicatesTableStructure.Insert("DuplicateRulesIndexTableAddress", "");
	
	DuplicateRulesIndexTable = 
		InformationRegisters.DuplicateRulesIndex.CreateRecordSet().UnloadColumns();
		
	If Not ObjectParameters.DeletionMark Then
		
		ObjMetadata = ObjectParameters.Ref.Metadata();
		ObjectTypeName = ObjMetadata.Name;
		ObjectType = Enums.DuplicateObjectsTypes[ObjectTypeName];
		
		// IndexTable for object
		PrepareDuplicateRulesIndexTableForObject(ObjectParameters, ObjectType, DuplicateRulesIndexTable);
		
		// Duplicates checking
		QueryNewObjectIndex = New Query;
		QueryNewObjectIndex.TempTablesManager = New TempTablesManager;
		QueryNewObjectIndex.Text = 
		"SELECT
		|	NewObjectIndex.HashSum AS HashSum,
		|	NewObjectIndex.ObjectType AS ObjectType,
		|	NewObjectIndex.ObjectCriteria AS ObjectCriteria,
		|	NewObjectIndex.ObjectRef AS ObjectRef,
		|	NewObjectIndex.Type AS Type,
		|	NewObjectIndex.Kind AS Kind,
		|	NewObjectIndex.Counterparty AS Counterparty,
		|	NewObjectIndex.Presentation AS Presentation
		|INTO NewObjectIndex
		|FROM
		|	&NewObjectIndex AS NewObjectIndex";
		QueryNewObjectIndex.SetParameter("NewObjectIndex", DuplicateRulesIndexTable);
		QueryNewObjectIndex.Execute();
		
		Query = New Query;
		Query.TempTablesManager = QueryNewObjectIndex.TempTablesManager;
		Query.Text = 
		"SELECT
		|	DuplicateRules.TypeOfExistingObject AS TypeOfExistingObject,
		|	DuplicateRulesMatchingCriterias.CriteriaOfNewObject AS CriteriaOfNewObject,
		|	DuplicateRulesMatchingCriterias.CriteriaOfExistingObject AS CriteriaOfExistingObject,
		|	DuplicateRules.TypeOfNewObject AS TypeOfNewObject
		|INTO MatchingCriterias
		|FROM
		|	Catalog.DuplicateRules.MatchingCriterias AS DuplicateRulesMatchingCriterias
		|		INNER JOIN Catalog.DuplicateRules AS DuplicateRules
		|		ON DuplicateRulesMatchingCriterias.Ref = DuplicateRules.Ref
		|WHERE
		|	DuplicateRules.TypeOfNewObject = &TypeOfNewObject
		|	AND DuplicateRulesMatchingCriterias.Use
		|	AND NOT DuplicateRules.DeletionMark
		|
		|INDEX BY
		|	CriteriaOfNewObject
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	NewObjectIndex.ObjectCriteria AS CriteriaOfNewObject,
		|	NewObjectIndex.HashSum AS HashSum,
		|	MatchingCriterias.TypeOfExistingObject AS TypeOfExistingObject,
		|	MatchingCriterias.CriteriaOfExistingObject AS CriteriaOfExistingObject
		|INTO ObjectCriterias
		|FROM
		|	MatchingCriterias AS MatchingCriterias
		|		INNER JOIN NewObjectIndex AS NewObjectIndex
		|		ON MatchingCriterias.CriteriaOfNewObject = NewObjectIndex.ObjectCriteria
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DuplicateRulesIndex.ObjectRef AS ObjectRef,
		|	DuplicateRulesIndex.HashSum AS HashSum
		|INTO DuplicateRefs
		|FROM
		|	ObjectCriterias AS ObjectCriterias
		|		INNER JOIN InformationRegister.DuplicateRulesIndex AS DuplicateRulesIndex
		|		ON ObjectCriterias.CriteriaOfExistingObject = DuplicateRulesIndex.ObjectCriteria
		|			AND ObjectCriterias.TypeOfExistingObject = DuplicateRulesIndex.ObjectType
		|			AND ObjectCriterias.HashSum = DuplicateRulesIndex.HashSum
		|WHERE
		|	DuplicateRulesIndex.ObjectRef <> &ObjectRef
		|
		|GROUP BY
		|	DuplicateRulesIndex.ObjectRef,
		|	DuplicateRulesIndex.HashSum
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DuplicateRulesIndex.HashSum AS HashSum,
		|	DuplicateRulesIndex.ObjectType AS ObjectType,
		|	DuplicateRulesIndex.ObjectCriteria AS ObjectCriteria,
		|	DuplicateRulesIndex.ObjectRef AS ObjectRef,
		|	DuplicateRulesIndex.Type AS Type,
		|	DuplicateRulesIndex.Kind AS Kind,
		|	DuplicateRulesIndex.Counterparty AS Counterparty,
		|	DuplicateRulesIndex.Presentation AS Presentation,
		|	DuplicateRulesIndex.HashSum = DuplicateRefs.HashSum AS IsDuplicate,
		|	FALSE AS NewObjectData
		|FROM
		|	InformationRegister.DuplicateRulesIndex AS DuplicateRulesIndex
		|		LEFT JOIN DuplicateRefs AS DuplicateRefs
		|		ON DuplicateRulesIndex.ObjectRef = DuplicateRefs.ObjectRef
		|			AND DuplicateRulesIndex.HashSum = DuplicateRefs.HashSum
		|WHERE
		|	DuplicateRulesIndex.ObjectRef IN
		|			(SELECT DISTINCT
		|				DuplicateRefs.ObjectRef AS ObjectRef
		|			FROM
		|				DuplicateRefs AS DuplicateRefs)
		|
		|ORDER BY
		|	ObjectCriteria
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	NewObjectIndex.HashSum AS HashSum,
		|	NewObjectIndex.ObjectType AS ObjectType,
		|	NewObjectIndex.ObjectCriteria AS ObjectCriteria,
		|	NewObjectIndex.ObjectRef AS ObjectRef,
		|	NewObjectIndex.Type AS Type,
		|	NewObjectIndex.Kind AS Kind,
		|	NewObjectIndex.Counterparty AS Counterparty,
		|	NewObjectIndex.Presentation AS Presentation,
		|	NewObjectIndex.HashSum = DuplicateRefs.HashSum AS IsDuplicate,
		|	TRUE AS NewObjectData
		|FROM
		|	NewObjectIndex AS NewObjectIndex
		|		LEFT JOIN DuplicateRefs AS DuplicateRefs
		|		ON NewObjectIndex.HashSum = DuplicateRefs.HashSum
		|
		|ORDER BY
		|	ObjectCriteria";
		
		Query.SetParameter("TypeOfNewObject", Enums.DuplicateObjectsTypes[ObjectTypeName]);
		Query.SetParameter("ObjectRef", ObjectParameters.Ref);
		
		// DuplicatesTableAddress
		QueryResult = Query.ExecuteBatch();
		If Not QueryResult[3].IsEmpty() Then
			DuplicatesTableStructure.DuplicatesTableAddress = PutToTempStorage(QueryResult[3].Unload());
		EndIf;
		
		// DuplicateRulesIndexTableAddress
		If Not QueryResult[4].IsEmpty() Then
			DuplicatesTableStructure.DuplicateRulesIndexTableAddress = PutToTempStorage(QueryResult[4].Unload());
		EndIf;
		
	EndIf;
	
	Return DuplicatesTableStructure;
	
EndFunction

Function MapObject(TypeOfNewObject, CriteriaOfNewObject, CriteriaValue) Export
	
	MappedObject = Undefined;
	
	DataHashing = New DataHashing(HashFunction.SHA256);
	DataHashing.Append(CriteriaValue);
	HashSum = Base64String(DataHashing.HashSum);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	DuplicateRules.TypeOfExistingObject AS TypeOfExistingObject,
		|	DuplicateRulesMatchingCriterias.CriteriaOfExistingObject AS CriteriaOfExistingObject
		|INTO MatchingCriterias
		|FROM
		|	Catalog.DuplicateRules.MatchingCriterias AS DuplicateRulesMatchingCriterias
		|		INNER JOIN Catalog.DuplicateRules AS DuplicateRules
		|		ON DuplicateRulesMatchingCriterias.Ref = DuplicateRules.Ref
		|WHERE
		|	DuplicateRules.TypeOfNewObject = &TypeOfNewObject
		|	AND DuplicateRulesMatchingCriterias.Use
		|	AND NOT DuplicateRules.DeletionMark
		|	AND DuplicateRulesMatchingCriterias.CriteriaOfNewObject = &CriteriaOfNewObject
		|	AND DuplicateRules.TypeOfExistingObject = &TypeOfNewObject
		|
		|INDEX BY
		|	TypeOfExistingObject,
		|	CriteriaOfExistingObject
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DuplicateRulesIndex.ObjectRef AS ObjectRef
		|FROM
		|	MatchingCriterias AS MatchingCriterias
		|		INNER JOIN InformationRegister.DuplicateRulesIndex AS DuplicateRulesIndex
		|		ON MatchingCriterias.TypeOfExistingObject = DuplicateRulesIndex.ObjectType
		|			AND MatchingCriterias.CriteriaOfExistingObject = DuplicateRulesIndex.ObjectCriteria
		|			AND (DuplicateRulesIndex.HashSum = &HashSum)";
	
	Query.SetParameter("CriteriaOfNewObject",	CriteriaOfNewObject);
	Query.SetParameter("TypeOfNewObject",		TypeOfNewObject);
	Query.SetParameter("HashSum",				HashSum);

	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		MappedObject = SelectionDetailRecords.ObjectRef;
	EndIf;
	
	Return MappedObject;
	
EndFunction

#EndRegion

#Region DuplicatesDeletion

Procedure ChangeDuplicatesData(ModificationTable, Cancel) Export
	
	For Each Duplicate In ModificationTable Do
		
		CatalogObject = Duplicate.Object.GetObject();
		
		Try
			CatalogObject.Lock();
		Except
			TemplateText = NStr("en = 'Cannot lock the duplicate object %1 for changing'; ru = 'Невозможно заблокировать дублирующий объект %1 для его изменения';pl = 'Nie można zablokować duplikatu obiektu %1 do zmiany';es_ES = 'No se puede bloquear el duplicado del objeto %1 para modificar';es_CO = 'No se puede bloquear el duplicado del objeto %1 para modificar';tr = 'Yinelenen nesne %1 değişmek üzere kilitlenemiyor';it = 'Non è possibile bloccare l''oggetto duplicato %1 per la modifica';de = 'Das duplizierte Objekt %1 kann nicht zum Ändern gesperrt werden.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(TemplateText, Duplicate.Object)
				+ Chars.LF + ErrorDescription();
			DriveServer.ShowMessageAboutError(Undefined, MessageText, , , , Cancel);
			Continue;
		EndTry;
		
		If Duplicate.Delete Then
			
			CatalogObject.DeletionMark = True;
			
		Else
			
			CatalogMetadata = Duplicate.Object.Metadata();
			CatalogName = CatalogMetadata.FullName();
			
			For Each LineToChange In Duplicate.ChangedAttributes Do
				
				If LineToChange.ObjectCriteria = Enums.DuplicateObjectsCriterias.ContactInformation Then
					
					Kind = GetCIKind(CatalogName, LineToChange.Type);
					FieldValues = ContactsManager.ContactsByPresentation(LineToChange.Presentation, Kind);
					ContactsManager.WriteContactInformation(CatalogObject, FieldValues, Kind, LineToChange.Type);
					
				Else
					
					AttributeName = XMLString(LineToChange.ObjectCriteria);
					
					If CatalogMetadata.Attributes.Find(AttributeName) <> Undefined Then
						
						CatalogObject[AttributeName] = LineToChange.Presentation;
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		CatalogObject.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

Function MatchingCriteriasTable()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties) AS TypeOfNewObject,
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties) AS TypeOfExistingObject,
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation) AS CriteriaOfNewObject,
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation) AS CriteriaOfExistingObject
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsCriterias.DescriptionFull),
		|	VALUE(Enum.DuplicateObjectsCriterias.DescriptionFull)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsCriterias.VATNumber),
		|	VALUE(Enum.DuplicateObjectsCriterias.VATNumber)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsCriterias.RegistrationNumber),
		|	VALUE(Enum.DuplicateObjectsCriterias.RegistrationNumber)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation),
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.ContactPersons),
		|	VALUE(Enum.DuplicateObjectsTypes.ContactPersons),
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation),
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.ContactPersons),
		|	VALUE(Enum.DuplicateObjectsTypes.ContactPersons),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.ContactPersons),
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation),
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.ContactPersons),
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation),
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsTypes.ContactPersons),
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation),
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsTypes.ContactPersons),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation),
		|	VALUE(Enum.DuplicateObjectsCriterias.ContactInformation)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Products),
		|	VALUE(Enum.DuplicateObjectsTypes.Products),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Products),
		|	VALUE(Enum.DuplicateObjectsTypes.Products),
		|	VALUE(Enum.DuplicateObjectsCriterias.SKU),
		|	VALUE(Enum.DuplicateObjectsCriterias.SKU)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description),
		|	VALUE(Enum.DuplicateObjectsCriterias.DescriptionFull)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsCriterias.DescriptionFull),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsCriterias.DescriptionFull),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description)
		|
		|UNION ALL
		|
		|SELECT
		|	VALUE(Enum.DuplicateObjectsTypes.Leads),
		|	VALUE(Enum.DuplicateObjectsTypes.Counterparties),
		|	VALUE(Enum.DuplicateObjectsCriterias.Description),
		|	VALUE(Enum.DuplicateObjectsCriterias.DescriptionFull)";
	
	Return Query.Execute().Unload();
	
EndFunction

Function ObjectCriteriasArray(ObjectType)
	
	MatchingCriteriasTable = MatchingCriteriasTable();
	
	Filter = New Structure();
	Filter.Insert("TypeOfNewObject", ObjectType);
	
	Rows = MatchingCriteriasTable.FindRows(Filter);
	
	ObjectCriterias = New Array;
	
	For Each Row In Rows Do
		If ObjectCriterias.Find(Row.CriteriaOfNewObject) = Undefined Then
			ObjectCriterias.Add(Row.CriteriaOfNewObject);
		EndIf;
	EndDo;
	
	Return ObjectCriterias;
	
EndFunction

Procedure PrepareDuplicateRulesIndexTableForObject(ObjectParameters, ObjectType, DuplicateRulesIndexTable)
	
	ObjectCriteriasArray = ObjectCriteriasArray(ObjectType);
	
	Counterparty = Catalogs.Counterparties.EmptyRef();
	TypeOfObject = TypeOf(ObjectParameters.Ref);
	If TypeOfObject = Type("CatalogRef.Leads") Then
		Counterparty = ObjectParameters.Counterparty;
	ElsIf TypeOfObject = Type("CatalogRef.Counterparties") Then
		Counterparty = ObjectParameters.Ref;
	ElsIf TypeOfObject = Type("CatalogRef.ContactPersons") Then
		Counterparty = ObjectParameters.Owner;
	EndIf;
	
	For Each Criteria In ObjectCriteriasArray Do
		
		If Criteria = Enums.DuplicateObjectsCriterias.ContactInformation Then
			
			For Each CILine In ObjectParameters.ContactInformation Do
				
				If ValueIsFilled(CILine.Presentation) Then
				
					NewLine = DuplicateRulesIndexTable.Add();
					NewLine.ObjectType = ObjectType;
					NewLine.ObjectCriteria = Criteria;
					NewLine.ObjectRef = ObjectParameters.Ref;
					NewLine.Type = CILine.Type;
					NewLine.Kind = CILine.Kind;
					NewLine.Counterparty = Counterparty;
					NewLine.Presentation = CILine.Presentation;
					DataHashing = New DataHashing(HashFunction.SHA256);
					DataHashing.Append(CILine.Presentation);
					NewLine.HashSum = Base64String(DataHashing.HashSum);
				
				EndIf;
				
			EndDo;
			
		Else
			
			AttributeName = XMLString(Criteria);
			
			If ValueIsFilled(ObjectParameters[AttributeName]) Then
				
				NewLine = DuplicateRulesIndexTable.Add();
				NewLine.ObjectType = ObjectType;
				NewLine.ObjectCriteria = Criteria;
				NewLine.ObjectRef = ObjectParameters.Ref;
				NewLine.Counterparty = Counterparty;
				NewLine.Presentation = ObjectParameters[AttributeName];
				DataHashing = New DataHashing(HashFunction.SHA256);
				DataHashing.Append(ObjectParameters[AttributeName]);
				NewLine.HashSum = Base64String(DataHashing.HashSum);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetCIKind(CatalogName, CIType)
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	ContactInformationTypes.Ref AS Ref
		|FROM
		|	Catalog.ContactInformationTypes AS ContactInformationTypes
		|WHERE
		|	ContactInformationTypes.Ref IN HIERARCHY(&RefFolder)
		|	AND ContactInformationTypes.Type = &Type
		|	AND NOT ContactInformationTypes.DeletionMark";
	
	Query.SetParameter("RefFolder", Catalogs.ContactInformationKinds[StrReplace(CatalogName, ".", "")]);
	Query.SetParameter("Type", CIType);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	Kind = Catalogs.ContactInformationKinds.EmptyRef();
	If SelectionDetailRecords.Next() Then
		Kind = SelectionDetailRecords.Ref;
	EndIf;
	
	Return Kind;
	
EndFunction

#EndRegion
