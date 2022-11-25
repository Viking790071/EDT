#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// If data is not updated but an update is possible, it updates, otherwise, it calls an exception.
// 
//
Procedure CheckRegisterData() Export
	
	Updated = StandardSubsystemsServer.ApplicationParameter(
		"StandardSubsystems.AccessManagement.RolesRights");
	
	If Updated <> Undefined Then
		Return;
	EndIf;
	
	UpdateRegisterData();
	
EndProcedure

// Updates the register data when changing a configuration.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	StandardSubsystemsCached.MetadataObjectIDsUsageCheck(True);
	
	Query = ChangesQuery(False);
	
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.RolesRights");
	
	BeginTransaction();
	Try
		Lock.Lock();
		Changes = Query.Execute().Unload();
		
		Data = New Structure;
		Data.Insert("RegisterManager",      InformationRegisters.RolesRights);
		Data.Insert("EditStringContent", Changes);
		
		AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
		
		StandardSubsystemsServer.AddApplicationParameterChanges(
			"StandardSubsystems.AccessManagement.RoleRightMetadataObjects",
			ChangedMetadataObjects(Changes));
		
		StandardSubsystemsServer.UpdateApplicationParameter(
			"StandardSubsystems.AccessManagement.RolesRights", True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Function AvailableMetadataObjectsRights()
	
	SetPrivilegedMode(True);
	
	MetadataObjectsRights = New ValueTable;
	MetadataObjectsRights.Columns.Add("Collection");
	MetadataObjectsRights.Columns.Add("InsertRight");
	MetadataObjectsRights.Columns.Add("EditRight");
	
	Row = MetadataObjectsRights.Add();
	Row.Collection         = "Catalogs";
	Row.InsertRight   = True;
	Row.EditRight    = True;
	
	Row = MetadataObjectsRights.Add();
	Row.Collection         = "Documents";
	Row.InsertRight   = True;
	Row.EditRight    = True;
	
	Row = MetadataObjectsRights.Add();
	Row.Collection         = "DocumentJournals";
	Row.InsertRight   = False;
	Row.EditRight    = False;
	
	Row = MetadataObjectsRights.Add();
	Row.Collection         = "ChartsOfCharacteristicTypes";
	Row.InsertRight   = True;
	Row.EditRight    = True;
	
	Row = MetadataObjectsRights.Add();
	Row.Collection         = "ChartsOfAccounts";
	Row.InsertRight   = True;
	Row.EditRight    = True;
	
	Row = MetadataObjectsRights.Add();
	Row.Collection         = "ChartsOfCalculationTypes";
	Row.InsertRight   = True;
	Row.EditRight    = True;
	
	Row = MetadataObjectsRights.Add();
	Row.Collection         = "InformationRegisters";
	Row.InsertRight   = False;
	Row.EditRight    = True;
	
	Row = MetadataObjectsRights.Add();
	Row.Collection         = "AccumulationRegisters";
	Row.InsertRight   = False;
	Row.EditRight    = True;
	
	Row = MetadataObjectsRights.Add();
	Row.Collection         = "AccountingRegisters";
	Row.InsertRight   = False;
	Row.EditRight    = True;
	
	Row = MetadataObjectsRights.Add();
	Row.Collection         = "CalculationRegisters";
	Row.InsertRight   = False;
	Row.EditRight    = True;
	
	Row = MetadataObjectsRights.Add();
	Row.Collection         = "BusinessProcesses";
	Row.InsertRight   = True;
	Row.EditRight    = True;
	
	Row = MetadataObjectsRights.Add();
	Row.Collection         = "Tasks";
	Row.InsertRight   = True;
	Row.EditRight    = True;
	
	Return MetadataObjectsRights;
	
EndFunction

// Returns object metadata fields that can be used to restrict access.
//
// Parameters:
//  MetadataObject - MetadataObject - an object that requires returning fields.
//  IBObject - Undefined - use the current configuration,
//                     - COMObject - use COM connection to configuration.
//  GetNamesArray - Boolean - a result type.
//
// Returns:
//  String - comma-separated names, if GetNamesArray = False.
//  Array - an array with values of the String type if GetNamesArray = True.
//
Function AllFieldsOfMetadataObjectAccessRestriction(MetadataObject,
                                                   FullName,
                                                   IBObject = Undefined,
                                                   GetNamesArray = False)
	
	CollectionsNames = New Array;
	TypeName = Left(FullName, StrFind(FullName, ".") - 1);
	
	If      TypeName = "Catalog" Then
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("TabularSections");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "Document" Then
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("TabularSections");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "DocumentJournal" Then
		CollectionsNames.Add("Columns");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "ChartOfCharacteristicTypes" Then
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("TabularSections");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "ChartOfAccounts" Then
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("TabularSections");
		CollectionsNames.Add("AccountingFlags");
		CollectionsNames.Add("StandardAttributes");
		CollectionsNames.Add("StandardTabularSections");
		
	ElsIf TypeName = "ChartOfCalculationTypes" Then
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("TabularSections");
		CollectionsNames.Add("StandardAttributes");
		CollectionsNames.Add("StandardTabularSections");
		
	ElsIf TypeName = "InformationRegister" Then
		CollectionsNames.Add("Dimensions");
		CollectionsNames.Add("Resources");
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "AccumulationRegister" Then
		CollectionsNames.Add("Dimensions");
		CollectionsNames.Add("Resources");
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "AccountingRegister" Then
		CollectionsNames.Add("Dimensions");
		CollectionsNames.Add("Resources");
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "CalculationRegister" Then
		CollectionsNames.Add("Dimensions");
		CollectionsNames.Add("Resources");
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "BusinessProcess" Then
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("TabularSections");
		CollectionsNames.Add("StandardAttributes");
		
	ElsIf TypeName = "Task" Then
		CollectionsNames.Add("AddressingAttributes");
		CollectionsNames.Add("Attributes");
		CollectionsNames.Add("TabularSections");
		CollectionsNames.Add("StandardAttributes");
	EndIf;
	
	FieldsNames = New Array;
	If IBObject = Undefined Then
		ValueStorageType = Type("ValueStorage");
	Else
		ValueStorageType = IBObject.NewObject("TypeDescription", "ValueStorage").Types().Get(0);
	EndIf;

	For each CollectionName In CollectionsNames Do
		If CollectionName = "TabularSections"
		 OR CollectionName = "StandardTabularSections" Then
			For each TabularSection In MetadataObject[CollectionName] Do
				AddFieldOfMetadataObjectAccessRestriction(MetadataObject, TabularSection.Name, FieldsNames, IBObject);
				Attributes = ?(CollectionName = "TabularSections", TabularSection.Attributes, TabularSection.StandardAttributes);
				For each Field In Attributes Do
					If Field.Type.ContainsType(ValueStorageType) Then
						Continue;
					EndIf;
					AddFieldOfMetadataObjectAccessRestriction(MetadataObject, TabularSection.Name + "." + Field.Name, FieldsNames, IBObject);
				EndDo;
				If CollectionName = "StandardTabularSections" AND TabularSection.Name = "ExtDimensionTypes" Then
					For each Field In MetadataObject.ExtDimensionAccountingFlags Do
						AddFieldOfMetadataObjectAccessRestriction(MetadataObject, "ExtDimensionTypes." + Field.Name, FieldsNames, IBObject);
					EndDo;
				EndIf;
			EndDo;
		Else
			For each Field In MetadataObject[CollectionName] Do
				If TypeName = "DocumentJournal"       AND Field.Name = "Type"
				 OR TypeName = "ChartOfCharacteristicTypes" AND Field.Name = "ValueType"
				 OR TypeName = "ChartOfAccounts"             AND Field.Name = "Kind"
				 OR TypeName = "AccumulationRegister"      AND Field.Name = "RecordType"
				 OR TypeName = "AccountingRegister"     AND CollectionName = "StandardAttributes" AND StrFind(Field.Name, "ExtDimensions") > 0 Then
					Continue;
				EndIf;
				If CollectionName = "Columns"
				 Or Field.Type.ContainsType(ValueStorageType) Then
					Continue;
				EndIf;
				If (CollectionName = "Dimensions" OR CollectionName = "Resources")
				   AND ?(IBObject = Undefined, Metadata, IBObject.Metadata).AccountingRegisters.Contains(MetadataObject)
				   AND NOT Field.Balance Then
					// Dr
					AddFieldOfMetadataObjectAccessRestriction(MetadataObject, Field.Name + "Dr", FieldsNames, IBObject);
					// Cr
					AddFieldOfMetadataObjectAccessRestriction(MetadataObject, Field.Name + "Cr", FieldsNames, IBObject);
				Else
					AddFieldOfMetadataObjectAccessRestriction(MetadataObject, Field.Name, FieldsNames, IBObject);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	If GetNamesArray Then
		Return FieldsNames;
	EndIf;
	
	FieldsList = "";
	For each FieldName In FieldsNames Do
		FieldsList = FieldsList + ", " + FieldName;
	EndDo;
	
	Return Mid(FieldsList, 3);
	
EndFunction

Procedure AddFieldOfMetadataObjectAccessRestriction(MetadataObject,
                                                          FieldName,
                                                          FieldsNames,
                                                          IBObject)
	
	Try
		If IBObject = Undefined Then
			AccessParameters("Read", MetadataObject, FieldName, Metadata.Roles.FullRights);
		Else
			IBObject.AccessParameters(
				"Read",
				MetadataObject,
				FieldName,
				IBObject.Metadata.Roles.FullRights);
		EndIf;
		CanGetAccessParameters = True;
	Except
		// If separate read restriction cannot be set for a field, any attempts to get access parameters for 
		// this field can generate errors.
		// These fields must be immediately excluded as they do not require checking for a restriction.
		CanGetAccessParameters = False;
	EndTry;
	
	If CanGetAccessParameters Then
		FieldsNames.Add(FieldName);
	EndIf;
	
EndProcedure

Function ChangesQuery(ExtensionsObjects) Export
	
	AvailableMetadataObjectsRights = AvailableMetadataObjectsRights();
	RolesRights = RolesRightsTable(ExtensionsObjects);
	
	Roles = New Array;
	FullNamesOfMetadataObjects = New Array;
	For Each Role In Metadata.Roles Do
		If ExtensionsObjects Then
			If Role.ConfigurationExtension() = Undefined
			   AND Not Role.ChangedByConfigurationExtensions() Then
				Continue;
			EndIf;
		ElsIf Role.ConfigurationExtension() <> Undefined Then
			Continue;
		EndIf;
		Roles.Add(Role);
		FullNamesOfMetadataObjects.Add(Role.FullName());
	EndDo;
	
	For Each AvailableRights In AvailableMetadataObjectsRights Do
		For Each MetadataObject In Metadata[AvailableRights.Collection] Do
			
            If Not ExtensionsObjects AND MetadataObject.ConfigurationExtension() <> Undefined Then
                Continue;
            EndIf;
			
			FullName = MetadataObject.FullName();
			FullNamesOfMetadataObjects.Add(FullName);
			Fields = Undefined;
			
			For Each Role In Roles Do
				
				If Not AccessRight("Read", MetadataObject, Role) Then
					Continue;
				EndIf;
				
				If Fields = Undefined Then
					Fields = AllFieldsOfMetadataObjectAccessRestriction(MetadataObject, FullName);
				EndIf;
				
				NewRow = RolesRights.Add();
				NewRow.RoleFullName = Role.FullName();
				NewRow.MetadataObjectFullName = FullName;
				
				NewRow.ReadWithoutRestriction = NOT AccessParameters("Read", MetadataObject, Fields, Role).RestrictionByCondition;
				NewRow.View = AccessRight("View", MetadataObject, Role);
				
				If AvailableRights.InsertRight AND AccessRight("Insert", MetadataObject, Role) Then
					NewRow.Insert = True;
					NewRow.InsertWithoutRestriction = NOT AccessParameters("Insert", MetadataObject, Fields, Role).RestrictionByCondition;
					NewRow.InteractiveInsert = AccessRight("InteractiveInsert", MetadataObject, Role);
				EndIf;
				
				If AvailableRights.EditRight AND AccessRight("Update", MetadataObject, Role) Then
					NewRow.Update = True;
					NewRow.UpdateWithoutRestriction = NOT AccessParameters("Update", MetadataObject, Fields, Role).RestrictionByCondition;
					NewRow.Edit = AccessRight("Edit", MetadataObject, Role);
				EndIf;
			EndDo;
			
		EndDo;
	EndDo;
	
	ObjectsIDs = Common.MetadataObjectIDs(FullNamesOfMetadataObjects);
	For Each Row In RolesRights Do
		Row.Role             = ObjectsIDs.Get(Row.RoleFullName);
		Row.MetadataObject = ObjectsIDs.Get(Row.MetadataObjectFullName);
	EndDo;
	
	TemporaryTablesQueriesText =
	"SELECT
	|	NewData.MetadataObject,
	|	NewData.Role,
	|	NewData.Insert,
	|	NewData.Update,
	|	NewData.ReadWithoutRestriction,
	|	NewData.InsertWithoutRestriction,
	|	NewData.UpdateWithoutRestriction,
	|	NewData.View,
	|	NewData.InteractiveInsert,
	|	NewData.Edit
	|INTO NewData
	|FROM
	|	&RolesRights AS NewData";
	
	QueryText =
	"SELECT
	|	NewData.MetadataObject,
	|	NewData.Role,
	|	NewData.Insert,
	|	NewData.Update,
	|	NewData.ReadWithoutRestriction,
	|	NewData.InsertWithoutRestriction,
	|	NewData.UpdateWithoutRestriction,
	|	NewData.View,
	|	NewData.InteractiveInsert,
	|	NewData.Edit,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	RolesFilterValue = ?(ExtensionsObjects, "&RoleFilterCriterion", Undefined);
	
	// Preparing the selected fields with optional filter.
	Fields = New Array;
	Fields.Add(New Structure("MetadataObject"));
	Fields.Add(New Structure("Role", RolesFilterValue));
	Fields.Add(New Structure("Insert"));
	Fields.Add(New Structure("Update"));
	Fields.Add(New Structure("ReadWithoutRestriction"));
	Fields.Add(New Structure("InsertWithoutRestriction"));
	Fields.Add(New Structure("UpdateWithoutRestriction"));
	Fields.Add(New Structure("View"));
	Fields.Add(New Structure("InteractiveInsert"));
	Fields.Add(New Structure("Edit"));
	
	Query = New Query;
	Query.SetParameter("RolesRights", RolesRights);
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.RolesRights", TemporaryTablesQueriesText);
		
	If ExtensionsObjects Then
		Table = RolesRights.Copy(, "Role");
		Table.GroupBy("Role");
		ModifiedRoles = Table.UnloadColumn("Role");
		AccessManagementInternal.SetFilterCriterionInQuery(Query, ModifiedRoles, "ModifiedRoles",
			"&RoleFilterCriterion:OldData.Role");
	EndIf;
	
	Return Query;
	
EndFunction

// Generates a blank table of role rights.
Function RolesRightsTable(ExtensionsObjects = False, RowChangeKind = False) Export

    RolesRights = CreateRecordSet().Unload();
    RolesRights.Columns.Add("RoleFullName",            New TypeDescription("String"));
    RolesRights.Columns.Add("MetadataObjectFullName", New TypeDescription("String"));

    If ExtensionsObjects Then
        // If the table is used for extension objects, extend the Role and MetadataObject types of columns 
        // with the CatalogRef.ExtensionObjectsIDs type.

        Types = New Array;
        Types.Add(Type("CatalogRef.MetadataObjectIDs"));
        Types.Add(Type("CatalogRef.ExtensionObjectIDs"));

        SetTypesForColumn(RolesRights, "Role", Types);
        SetTypesForColumn(RolesRights, "MetadataObject", Types);
    EndIf;

    If RowChangeKind Then
        RolesRights.Columns.Add("RowChangeKind", New TypeDescription("Number"));
    EndIf;

    Return RolesRights;

EndFunction

// It is required by the RolesRightsTable function.
Procedure SetTypesForColumn(Table, ColumnName, Types)

    Column = Table.Columns[ColumnName];
    ColumnProperties = New Structure("Name, Title, Width");
    FillPropertyValues(ColumnProperties, Column);
    Index = Table.Columns.IndexOf(Column);
    Table.Columns.Delete(Index);

    Table.Columns.Insert(Index, ColumnProperties.Name, New TypeDescription(Types),
        ColumnProperties.Title, ColumnProperties.Width);

EndProcedure
	
Function ChangedMetadataObjects(Changes) Export
	
	Changes.GroupBy("MetadataObject, Role, Insert, Update", "RowChangeKind");
	
	UnusedRows = Changes.FindRows(New Structure("RowChangeKind", 0));
	For each Row In UnusedRows Do
		Changes.Delete(Row);
	EndDo;
	
	Changes.GroupBy("MetadataObject");
	
	Return New FixedArray(Changes.UnloadColumn("MetadataObject"));
	
EndFunction

#EndRegion

#EndIf
