#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AdditionalReportsAndDataProcessors

// Gets data about an external processor.
//
// Returns:
//   Structure - see AdditionalReportsAndDataProcessors.ExternalDataProcessorInfo(). 
//
Function ExternalDataProcessorInfo() Export
	Var RegistrationParameters;
	
	If SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessorsClientServer = CommonModule("AdditionalReportsAndDataProcessorsClientServer");
		
		RegistrationParameters = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorInfo("2.1.3.1");
		
		RegistrationParameters.Kind = ModuleAdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalDataProcessor();
		RegistrationParameters.Version = "2.2.1";
		RegistrationParameters.SafeMode = False;
		
		NewCommand = RegistrationParameters.Commands.Add();
		NewCommand.Presentation = NStr("ru = 'Групповое изменение реквизитов'; en = 'Bulk attribute editing'; pl = 'Zbiorcza edycja atrybutów';es_ES = 'Edición del atributo grueso';es_CO = 'Edición del atributo grueso';tr = 'Toplu özellik düzenleme';it = 'Modifica collettiva degli attributi';de = 'Massenattributbearbeitung'");
		NewCommand.ID = "OpenGlobally";
		NewCommand.Use = ModuleAdditionalReportsAndDataProcessorsClientServer.CommandTypeOpenForm();
		NewCommand.ShowNotification = False;
	EndIf;
	
	Return RegistrationParameters;
	
EndFunction

// End StandardSubsystems.AdditionalReportsAndDataProcessors

#EndRegion

#EndRegion

#Region Private

// For internal use.
Function QueryText(TypesOfObjectsToChange, RestrictSelection = False) Export
	
	MetadataObjects = New Array;
	For Each ObjectName In StrSplit(TypesOfObjectsToChange, ",", False) Do
		MetadataObjects.Add(Metadata.FindByFullName(ObjectName));
	EndDo;
	
	ObjectsStructure = CommonObjectsAttributes(TypesOfObjectsToChange);
	
	Result = "";
	TableAlias = "SpecifiedTableAlias";
	For Each MetadataObject In MetadataObjects Do
		
		If Not IsBlankString(Result) Then
			Result = Result + Chars.LF + Chars.LF + "UNION ALL" + Chars.LF + Chars.LF;
		EndIf;
		
		QueryText = "";
		
		For Each AttributeName In ObjectsStructure.Attributes Do
			If Not IsBlankString(QueryText) Then
				QueryText = QueryText + "," + Chars.LF;
			EndIf;
			QueryText = QueryText + TableAlias + "." + AttributeName + " AS " + AttributeName;
		EndDo;
		
		For Each TabularSection In ObjectsStructure.TabularSections Do
			TabularSectionName = TabularSection.Key;
			QueryText = QueryText + "," + Chars.LF + TableAlias + "." + TabularSectionName + ".(";
			
			AttributesRow = "LineNumber";
			TabularSectionAttributes = TabularSection.Value;
			For Each AttributeName In TabularSectionAttributes Do
				If Not IsBlankString(AttributesRow) Then
					AttributesRow = AttributesRow + "," + Chars.LF;
				EndIf;
				AttributesRow = AttributesRow + AttributeName;
			EndDo;
			QueryText = QueryText + AttributesRow +"
			|)";
		EndDo;
		
		QueryText = "SELECT " + ?(RestrictSelection, "TOP 1001 ", "") + QueryText + Chars.LF + "
			|FROM
			|	"+ MetadataObject.FullName() + " AS " + TableAlias;
			
		Result = Result + QueryText;
	EndDo;
		
		
	Return Result;
	
EndFunction

Function CommonObjectsAttributes(ObjectsTypes) Export
	
	MetadataObjects = New Array;
	For Each ObjectName In StrSplit(ObjectsTypes, ",", False) Do
		MetadataObjects.Add(Metadata.FindByFullName(ObjectName));
	EndDo;
	
	Result = New Structure;
	Result.Insert("Attributes", New Array);
	Result.Insert("TabularSections", New Structure);
	
	CommonAttributesList = ItemList(MetadataObjects[0].Attributes, False);
	For Index = 1 To MetadataObjects.Count() - 1 Do
		CommonAttributesList = AttributesIntersection(CommonAttributesList, MetadataObjects[Index].Attributes);
	EndDo;
	
	StandardAttributes = MetadataObjects[0].StandardAttributes;
	For Index = 1 To MetadataObjects.Count() - 1 Do
		StandardAttributes = AttributesIntersection(StandardAttributes, MetadataObjects[Index].StandardAttributes);
	EndDo;
	For Each Attribute In StandardAttributes Do
		CommonAttributesList.Add(Attribute);
	EndDo;
	
	Result.Attributes = ItemList(CommonAttributesList);
	
	TabularSections = ItemList(MetadataObjects[0].TabularSections);
	For Index = 1 To MetadataObjects.Count() - 1 Do
		TabularSections = SetIntersection(TabularSections, ItemList(MetadataObjects[Index].TabularSections));
	EndDo;
	
	For Each TabularSectionName In TabularSections Do
		TabularSectionAttributes = ItemList(MetadataObjects[0].TabularSections[TabularSectionName].Attributes, False);
		For Index = 1 To MetadataObjects.Count() - 1 Do
			TabularSectionAttributes = AttributesIntersection(TabularSectionAttributes, MetadataObjects[Index].TabularSections[TabularSectionName].Attributes);
		EndDo;
		If TabularSectionAttributes.Count() > 0 Then
			Result.TabularSections.Insert(TabularSectionName, ItemList(TabularSectionAttributes));
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function ItemList(Collection, NamesOnly = True)
	Result = New Array;
	For Each Item In Collection Do
		If NamesOnly Then
			Result.Add(Item.Name);
		Else
			Result.Add(Item);
		EndIf;
	EndDo;
	Return Result;
EndFunction

Function SetIntersection(Set1, Set2) Export
	
	Result = New Array;
	
	For Each Item In Set2 Do
		Index = Set1.Find(Item);
		If Index <> Undefined Then
			Result.Add(Item);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function AttributesIntersection(AttributesCollection1, AttributesCollection2)
	
	Result = New Array;
	
	For Each Attribute2 In AttributesCollection2 Do
		For Each Attribute1 In AttributesCollection1 Do
			If Attribute1.Name = Attribute2.Name 
				AND (Attribute1.Type = Attribute2.Type Or Attribute1.Name = "Ref") Then
				Result.Add(Attribute1);
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

// For internal use.
Function DataCompositionSchema(QueryText) Export
	DataCompositionSchema = New DataCompositionSchema;
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.DataSource = "DataSource1";
	DataSet.AutoFillAvailableFields = True;
	DataSet.Query = QueryText;
	DataSet.Name = "DataSet1";
	
	Return DataCompositionSchema;
EndFunction

// For internal use.
Procedure ChangeObjects(Parameters, ResultAddress) Export
	
	ObjectsToProcess = Parameters.ObjectsToProcess.Get().Rows;
	ObjectsForChanging = Parameters.ObjectsForChanging.Get().Rows;
	
	ChangeResult = New Structure("HasErrors, ProcessingState");
	ChangeResult.HasErrors = False;
	ChangeResult.ProcessingState = New Map;
	
	If ObjectsToProcess = Undefined Then
		ObjectsToProcess = New Array;
		For Each ObjectToChange In ObjectsForChanging Do
			ObjectsToProcess.Add(ObjectToChange);
		EndDo;
	EndIf;
	
	If ObjectsToProcess.Count() = 0 Then
		PutToTempStorage(ChangeResult, ResultAddress);
		Return;
	EndIf;
	
	If Parameters.OperationType = "ExecuteAlgorithm" AND DataSeparationEnabled() Then
		PutToTempStorage(ChangeResult, ResultAddress);
		Return;
	EndIf;
	
	StopChangeOnError = Parameters.StopChangeOnError;
	If StopChangeOnError = Undefined Then
		StopChangeOnError = Parameters.InterruptOnError;
	EndIf;
	CheckForGroup = CheckForGroup(ObjectsToProcess[0].Ref);
	WriteError = True;
	Ref = Undefined;
	RunAlgorithmCodeInSafeMode = (Parameters.ExecutionMode <> 1);
	
	DisableAccessKeysUpdate(True);
	If Parameters.ChangeInTransaction Then
		BeginTransaction(DataLockControlMode.Managed);
	EndIf;
	
	Try
		If Parameters.ChangeInTransaction Then
			For Each ObjectData In ObjectsToProcess Do
				LockRef(ObjectData.Ref);
			EndDo;
		EndIf;
		
		For Each ObjectData In ObjectsToProcess Do
			
			WriteError = True;
			BeginTransaction(DataLockControlMode.Managed);
			Try
				
				Ref = ObjectData.Ref;
				If Not Parameters.ChangeInTransaction Then
					LockRef(Ref);
				EndIf;
			
				ObjectToChange = Ref.GetObject();
				
				Changes = Undefined;
				If Parameters.OperationType = "ExecuteAlgorithm" Then
					RunAlgorithmCode(ObjectToChange, Parameters.AlgorithmCode, RunAlgorithmCodeInSafeMode);
				Else
					Changes = MakeChanges(ObjectData, ObjectToChange, Parameters, CheckForGroup);
				EndIf;
				
				// Write mode.
				IsDocument = Metadata.Documents.Contains(ObjectToChange.Metadata());
				WriteMode = DetermineWriteMode(ObjectToChange, IsDocument, Parameters.DeveloperMode);
				
				// Checking whether the values are filled.
				If Not Parameters.DeveloperMode Then
					If Not IsDocument Or WriteMode = DocumentWriteMode.Posting Then
						If Not ObjectToChange.CheckFilling() Then
							Raise FillCheckErrorsText();
						EndIf;
					EndIf;
				EndIf;
				
				// Writing additional info.
				If Changes <> Undefined AND Changes.AddInfoRecordsArray.Count() > 0 Then
					For Each RecordManager In Changes.AddInfoRecordsArray Do
						RecordManager.Write(True);
					EndDo;
				EndIf;
				
				MustWriteObject = (Parameters.ObjectWriteOption <> "DoNotWrite");
				
				// Writing object.
				If MustWriteObject Then
					If WriteMode <> Undefined Then
						ObjectToChange.Write(WriteMode);
					Else
						ObjectToChange.Write();
					EndIf;
				EndIf;
				
				FillAdditionalPropertiesChangeResult(ChangeResult, Ref, ObjectToChange, Changes);
				
				UnlockDataForEdit(Ref);
				CommitTransaction();
				
			Except
				
				RollbackTransaction();
				If Parameters.ChangeInTransaction Then
					UnlockDataForEdit(Ref);
				EndIf;
				
				BriefErrorPresentation = BriefErrorDescription(ErrorInfo());
				FillChangeResult(ChangeResult, Ref, BriefErrorPresentation);
				If StopChangeOnError Or Parameters.ChangeInTransaction Then
					WriteError = False;
					Raise;
				EndIf;
				
				Continue;
			EndTry;
			
		EndDo;
		
		DisableAccessKeysUpdate(False);
		If Parameters.ChangeInTransaction Then
			CommitTransaction();
		EndIf;
		
	Except
		
		If Parameters.ChangeInTransaction Then 
			RollbackTransaction();
			For Each ObjectData In ObjectsToProcess Do
				UnlockDataForEdit(ObjectData.Ref);
			EndDo;
		EndIf;
		
		DisableAccessKeysUpdate(False, Parameters.ChangeInTransaction);
		
		If WriteError Then
			BriefErrorPresentation = BriefErrorDescription(ErrorInfo());
			FillChangeResult(ChangeResult, Ref, BriefErrorPresentation);
		EndIf;
		
	EndTry;
	
	PutToTempStorage(ChangeResult, ResultAddress);
	
EndProcedure

Procedure LockRef(Val Ref)
	
	LockDataForEdit(Ref);
	Lock = New DataLock;
	LockItem = Lock.Add(ObjectKindByRef(Ref) + "." + Ref.Metadata().Name);
	LockItem.SetValue("Ref", Ref);
	Lock.Lock();

EndProcedure

Function MakeChanges(Val ObjectData, Val ObjectToChange, Val Parameters, Val CheckForGroup)
	
	Result = New Structure;
	Result.Insert("ObjectAttributesToChange", New Array);
	Result.Insert("AdditionalObjectAttributesToChange", New Map);
	Result.Insert("AdditionalObjectInfoToChange", New Map);
	Result.Insert("AddInfoRecordsArray", New Array);
	
	// Effecting the changes.
	For Each Operation In Parameters.AttributesToChange Do
		
		Value = EvalExpression(Operation.Value, ObjectToChange, Parameters.AvailableAttributes);
		If Operation.OperationKind = 1 Then // Changing an attribute
			// Omitting missing group attributes.
			If CheckForGroup AND ObjectToChange.IsFolder Then
				If NOT IsStandardAttribute(ObjectToChange.Metadata().StandardAttributes, Operation.Name) Then
					Continue;
				EndIf;
			EndIf;
			
			ObjectToChange[Operation.Name] = Value;
			Result.ObjectAttributesToChange.Add(Operation.Name);
			
		ElsIf Operation.OperationKind = 2 Then // Changing an additional attribute
			
			If Not PropertyMustChange(ObjectToChange.Ref, Operation.Property, Parameters) Then
				Continue;
			EndIf;
			
			FoundRow = ObjectToChange.AdditionalAttributes.Find(Operation.Property, "Property");
			If ValueIsFilled(Value) Then
				If FoundRow = Undefined Then
					FoundRow = ObjectToChange.AdditionalAttributes.Add();
					FoundRow.Property = Operation.Property;
				EndIf;
				FoundRow.Value = Value;
				
				PropertyDetails = ObjectAttributesValues(Operation.Property, "ValueType, MultilineInputField");
				ModulePropertyManager = CommonModule("PropertyManagerInternal");
				If ModulePropertyManager.UseUnlimitedString(PropertyDetails.ValueType, PropertyDetails.MultilineInputField) Then
					FoundRow.TextString = Value;
				EndIf;
			Else
				If FoundRow <> Undefined Then
					ObjectToChange.AdditionalAttributes.Delete(FoundRow);
				EndIf;
			EndIf;
			
			FormAttributeName = AddAttributeNamePrefix() + StrReplace(String(Operation.Property.UUID()), "-", "_");
			Result.AdditionalObjectAttributesToChange.Insert(FormAttributeName, Value);
			
		ElsIf Operation.OperationKind = 3 Then // Changing additional info
			
			If Not PropertyMustChange(ObjectToChange.Ref, Operation.Property, Parameters) Then
				Continue;
			EndIf;
			
			RecordManager = InformationRegisters["AdditionalInfo"].CreateRecordManager();
			RecordManager.Object = ObjectToChange.Ref;
			RecordManager.Property = Operation.Property;
			RecordManager.Value = Value;
			Result.AddInfoRecordsArray.Add(RecordManager);
			
			FormAttributeName = AddInfoNamePrefix() + StrReplace(String(Operation.Property.UUID()), "-", "_");
			Result.AdditionalObjectInfoToChange.Insert(FormAttributeName, Value);
			
		EndIf;
		
	EndDo;
	
	If Parameters.TabularSectionsToChange.Count() > 0 Then
		MakeChangesToTabularSections(ObjectToChange, ObjectData, Parameters.TabularSectionsToChange);
	EndIf;

	Return Result;
	
EndFunction

Procedure RunAlgorithmCode(Val Object, Val AlgorithmCode, Val ExecuteInSafeMode)
	
	If ExecuteInSafeMode Or NOT AccessRight("Administration", Metadata) Then
		AlgorithmCode = StrReplace(AlgorithmCode, "Object.", "Parameters.");
		ExecuteInSafeMode(AlgorithmCode, Object);
	Else
		Execute AlgorithmCode;
	EndIf;
	
EndProcedure

Function DataSeparationEnabled()
	
	SaaSAvailable = Metadata.FunctionalOptions.Find("SaaS");
	If SaaSAvailable <> Undefined Then
		OptionName = "SaaS";
		Return IsSeparatedConfiguration() AND GetFunctionalOption(OptionName);
	EndIf;
	
	Return False;
	
EndFunction

// Returns a flag that shows if there are any common separators in the configuration.
//
// Returns:
// Boolean.
//
Function IsSeparatedConfiguration()
	
	HasSeparators = False;
	For each CommonAttribute In Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			HasSeparators = True;
			Break;
		EndIf;
	EndDo;
	
	Return HasSeparators;
	
EndFunction

Function DetermineWriteMode(Val ObjectToChange, Val IsDocument, Val DeveloperMode)
	
	WriteMode = Undefined;
	If DeveloperMode Then
		WriteMode = Undefined;
		ObjectToChange.DataExchange.Load = True;
	ElsIf IsDocument Then
		WriteMode = DocumentWriteMode.Write;
		If ObjectToChange.Posted Then
			WriteMode = DocumentWriteMode.Posting;
		ElsIf ObjectToChange.Metadata().Posting = Metadata.ObjectProperties.Posting.Allow Then
			WriteMode = DocumentWriteMode.UndoPosting;
		EndIf;
	EndIf;
	Return WriteMode;

EndFunction

Function PropertyMustChange(Ref, Property, Parameters)
	
	If SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = CommonModule("PropertyManager");
		If ModulePropertyManager = Undefined Then
			Return False;
		EndIf;
	EndIf;
	
	ObjectKindByRef = ObjectKindByRef(Ref);
	If (ObjectKindByRef = "Catalog" OR ObjectKindByRef = "ChartOfCharacteristicTypes")
		AND ObjectIsFolder(Ref) Then
		Return False;
	EndIf;
	
	If NOT ModulePropertyManager.CheckObjectProperty(Ref, Property) Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function FillCheckErrorsText()
	
	Result = "";
	MessagesArray = GetUserMessages(True);
	
	For Each UserMessage In MessagesArray Do
		Result = Result + UserMessage.Text + Chars.LF;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure FillChangeResult(Result, Ref, ErrorMessage)
	
	ChangeStatus = New Structure;
	ChangeStatus.Insert("ErrorCode", "Error");
	ChangeStatus.Insert("ErrorMessage", ErrorMessage);
	
	Result.ProcessingState.Insert(Ref, ChangeStatus);
	Result.HasErrors = True;
	
EndProcedure

Procedure FillAdditionalPropertiesChangeResult(Result, Ref, ObjectToChange, Changes = Undefined)
	
	ChangeStatus = New Structure;
	ChangeStatus.Insert("ErrorCode", "");
	ChangeStatus.Insert("ErrorMessage", "");
	ChangeStatus.Insert("ChangedAttributesValues", New Map);
	If Changes <> Undefined Then
		For Each AttributeName In Changes.ObjectAttributesToChange Do
			ChangeStatus.ChangedAttributesValues.Insert(AttributeName, ObjectToChange[AttributeName]);
		EndDo;
	EndIf;
	ChangeStatus.Insert("ChangedAddAttributesValues", 
		?(Changes <> Undefined, Changes.AdditionalObjectAttributesToChange, Changes));
	ChangeStatus.Insert("ChangedAddInfoValues", 
		?(Changes <> Undefined, Changes.AdditionalObjectInfoToChange, Changes));
	
	Result.ProcessingState.Insert(Ref, ChangeStatus);
	
EndProcedure

Function AddAttributeNamePrefix()
	Return "AddlAttribute_";
EndFunction

Function AddInfoNamePrefix()
	Return "AddlDataItem_";
EndFunction

Function CheckForGroup(Ref)
	
	ObjectKind = ObjectKindByRef(Ref);
	ObjectMetadata = Ref.Metadata();
	
	If ObjectKind = "Catalog"
	   AND ObjectMetadata.Hierarchical
	   AND ObjectMetadata.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
		
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

Procedure MakeChangesToTabularSections(ObjectToChange, ObjectData, ChangesToTabularSections)
	
	For Each TabularSectionChanges In ChangesToTabularSections Do
		TableName = TabularSectionChanges.Key;
		AttributesToChange = TabularSectionChanges.Value;
		For Each TableRow In ObjectToChange[TableName] Do
			If StringMatchesFilter(TableRow, ObjectData, TableName) Then
				For Each AttributeToChange In AttributesToChange Do
					TableRow[AttributeToChange.Name] = AttributeToChange.Value;
				EndDo;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

Function StringMatchesFilter(TableRow, ObjectData, TableName)
	
	Return ObjectData.Rows.FindRows(New Structure(TableName + "LineNumber", TableRow.LineNumber)).Count() = 1;
	
EndFunction

Procedure FillEditableObjectsCollection(AvailableObjects, ShowHiddenItems) Export

	MetadataObjectsCollections = New Array;
	MetadataObjectsCollections.Add(Metadata.Catalogs);
	MetadataObjectsCollections.Add(Metadata.Documents);
	MetadataObjectsCollections.Add(Metadata.BusinessProcesses);
	MetadataObjectsCollections.Add(Metadata.Tasks);
	MetadataObjectsCollections.Add(Metadata.ChartsOfCalculationTypes);
	MetadataObjectsCollections.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataObjectsCollections.Add(Metadata.ChartsOfAccounts);
	MetadataObjectsCollections.Add(Metadata.ExchangePlans);
	
	PrefixOfObjectsToDelete = "delete";
	ObjectsToDelete = New ValueList;
	
	ObjectsManagers = Undefined;
	If SSLVersionMatchesRequirements() Then
		ObjectsManagers = ObjectsManagersForEditingAttributes();
	EndIf;
	
	For Each MetadataObjectsCollection In MetadataObjectsCollections Do
		For Each MetadataObject In MetadataObjectsCollection Do
			If Not ShowHiddenItems Then
				If StrStartsWith(Lower(MetadataObject.Name),PrefixOfObjectsToDelete)
					Or IsInternalObject(MetadataObject, ObjectsManagers) Then
					Continue;
				EndIf;
			EndIf;
			
			If AccessRight("Update", MetadataObject) Then
				If StrStartsWith(Lower(MetadataObject.Name),PrefixOfObjectsToDelete) Then
					ObjectsToDelete.Add(MetadataObject.FullName(), MetadataObject.Presentation());
				Else 
					AvailableObjects.Add(MetadataObject.FullName(), MetadataObject.Presentation());
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	AvailableObjects.SortByPresentation();
	ObjectsToDelete.SortByPresentation();
	
	For Each Item In ObjectsToDelete Do
		AvailableObjects.Add(Item.Value, Item.Presentation);
	EndDo;
	
EndProcedure

Function IsInternalObject(MetadataObject, ObjectsManagers)
	
	If ObjectsManagers <> Undefined Then
		AvailableMethods = ObjectManagerMethodsForEditingAttributes(MetadataObject.FullName(), ObjectsManagers);
		If TypeOf(AvailableMethods) = Type("Array") AND (AvailableMethods.Count() = 0 
			Or AvailableMethods.Find("AttributesToEditInBatchProcessing") <> Undefined) Then
				ObjectManager = ObjectManagerByFullName(MetadataObject.FullName());
				ToEdit = ObjectManager.AttributesToEditInBatchProcessing();
		EndIf;
	Else
		// Checking if there are editable attributes in case of no-SSL or old-SSL configurations.
		// 
		ObjectManager = ObjectManagerByFullName(MetadataObject.FullName());
		Try
			ToEdit = ObjectManager.AttributesToEditInBatchProcessing();
		Except
			// Method not found
			ToEdit = Undefined;
		EndTry;
	EndIf;
	
	If ToEdit <> Undefined AND ToEdit.Count() = 0 Then
		Return True;
	EndIf;
	
	//
	
	If ObjectsManagers <> Undefined Then
		If TypeOf(AvailableMethods) = Type("Array") AND (AvailableMethods.Count() = 0
			Or AvailableMethods.Find("AttributesToSkipInBatchProcessing") <> Undefined) Then
				If ObjectManager = Undefined Then
					ObjectManager = ObjectManagerByFullName(MetadataObject.FullName());
				EndIf;	
				ToSkip = ObjectManager.AttributesToSkipInBatchProcessing();
		EndIf;
		
	Else
		// Checking if there are non-editable attributes in case of no-SSL or old-SSL configurations.
		// 
		Try
			ToSkip = ObjectManager.AttributesToSkipInBatchProcessing();
		Except
			// Method not found
			ToSkip = Undefined;
		EndTry;
	EndIf;
	
	If ToSkip <> Undefined AND ToSkip.Find("*") <> Undefined Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function ObjectManagerMethodsForEditingAttributes(ObjectName, ObjectsManagers)
	
	InformationOnObjectManager = ObjectsManagers[ObjectName];
	If InformationOnObjectManager = Undefined Then
		Return "Unsupported";
	EndIf;
	AvailableMethods = StrSplit(InformationOnObjectManager, Chars.LF, False);
	Return AvailableMethods;
	
EndFunction

Function ObjectsManagersForEditingAttributes()
	
	ModuleSubsystemIntegrationSSL = CommonModule("SSLSubsystemsIntegration");
	ModuleBatchObjectModificationOverridable = CommonModule("BatchEditObjectsOverridable");
	If ModuleSubsystemIntegrationSSL = Undefined Or ModuleBatchObjectModificationOverridable = Undefined Then
		Return New Array;
	EndIf;
	
	ObjectsWithLockedAttributes = New Map;
	ModuleSubsystemIntegrationSSL.OnDefineObjectsWithEditableAttributes(ObjectsWithLockedAttributes);
	ModuleBatchObjectModificationOverridable.OnDefineObjectsWithEditableAttributes(ObjectsWithLockedAttributes);
	
	Return ObjectsWithLockedAttributes;
	
EndFunction

Function SSLVersionMatchesRequirements() Export
	
	Try
		ModuleStandardSubsystemsServer = CommonModule("StandardSubsystemsServer");
	Except
		// Module not available
		ModuleStandardSubsystemsServer = Undefined;
	EndTry;
	If ModuleStandardSubsystemsServer = Undefined Then 
		Return False;
	EndIf;
	
	SSLVersion = ModuleStandardSubsystemsServer.LibraryVersion();
	Return CompareVersions(SSLVersion, "3.0.1.1") >= 0;
	
EndFunction

// Compares two versions in the String format.
//
// Parameters:
//  VersionString1  - String - the first version in the RR.{S|SS}.VV.BB format.
//  VersionString2  - String - the second version.
//
// Returns:
//   Number - if VersionString1 > VersionString2, it is a positive number. If they are equal, it is 0.
//
Function CompareVersions(Val VersionString1, Val VersionString2) Export
	
	String1 = ?(IsBlankString(VersionString1), "0.0.0.0", VersionString1);
	String2 = ?(IsBlankString(VersionString2), "0.0.0.0", VersionString2);
	Version1 = StrSplit(String1, ".");
	If Version1.Count() <> 4 Then
		Raise SubstituteParametersToString(
			NStr("ru = 'Неправильный формат параметра VersionString1: %1'; en = 'Invalid format of VersionString1 parameter: %1.'; pl = 'Niepoprawny format dla parametru VersionString1: %1.';es_ES = 'Formato inválido para el parámetro VersiónFila1:%1';es_CO = 'Formato inválido para el parámetro VersiónFila1:%1';tr = 'VersionString1 parametresi için geçersiz biçim: %1.';it = 'Il formato del parametro RigaVersione1: %1 è incorretto.';de = 'Ungültiges Format für Parameter Version Reihe1: %1.'"), VersionString1);
	EndIf;
	Version2 = StrSplit(String2, ".");
	If Version2.Count() <> 4 Then
		Raise SubstituteParametersToString(
			NStr("ru = 'Неправильный формат параметра VersionString2: %1'; en = 'Invalid format of the VersionString2 parameter: %1.'; pl = 'Niepoprawny format dla parametru VersionString2: %1.';es_ES = 'Formato inválido para el parámetro VersiónFila2:%1';es_CO = 'Formato inválido para el parámetro VersiónFila2:%1';tr = 'VersionString2 parametresi için geçersiz biçim: %1.';it = 'Il formato del parametro RigaVersione2: %1 è incorretto.';de = 'Ungültiges Format für Parameter Version Reihe2: %1.'"), VersionString2);
	EndIf;
	
	Result = 0;
	For Digit = 0 To 3 Do
		Result = Number(Version1[Digit]) - Number(Version2[Digit]);
		If Result <> 0 Then
			Return Result;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

Function ObjectManagerByFullName(FullName)
	Var MOClass, MetadataObjectName, Manager;
	
	NameParts = StrSplit(FullName, ".");
	
	If NameParts.Count() = 2 Then
		MOClass = NameParts[0];
		MetadataObjectName  = NameParts[1];
	EndIf;
	
	If      Upper(MOClass) = "EXCHANGEPLAN" Then
		Manager = ExchangePlans;
		
	ElsIf Upper(MOClass) = "CATALOG" Then
		Manager = Catalogs;
		
	ElsIf Upper(MOClass) = "DOCUMENT" Then
		Manager = Documents;
		
	ElsIf Upper(MOClass) = "DOCUMENTJOURNAL" Then
		Manager = DocumentJournals;
		
	ElsIf Upper(MOClass) = "ENUM" Then
		Manager = Enums;
		
	ElsIf Upper(MOClass) = "REPORT" Then
		Manager = Reports;
		
	ElsIf Upper(MOClass) = "DATAPROCESSOR" Then
		Manager = DataProcessors;
		
	ElsIf Upper(MOClass) = "CHARTOFCHARACTERISTICTYPES" Then
		Manager = ChartsOfCharacteristicTypes;
		
	ElsIf Upper(MOClass) = "CHARTOFACCOUNTS" Then
		Manager = ChartsOfAccounts;
		
	ElsIf Upper(MOClass) = "CHARTOFCALCULATIONTYPES" Then
		Manager = ChartsOfCalculationTypes;
		
	ElsIf Upper(MOClass) = "INFORMATIONREGISTER" Then
		Manager = InformationRegisters;
		
	ElsIf Upper(MOClass) = "ACCUMULATIONREGISTER" Then
		Manager = AccumulationRegisters;
		
	ElsIf Upper(MOClass) = "ACCOUNTINGREGISTER" Then
		Manager = AccountingRegisters;
		
	ElsIf Upper(MOClass) = "CALCULATIONREGISTER" Then
		If NameParts.Count() = 2 Then
			// Calculation register
			Manager = CalculationRegisters;
		Else
			SubordinateMOClass = NameParts[2];
			SubordinateMOName = NameParts[3];
			If Upper(SubordinateMOClass) = "RECALCULATION" Then
				// Recalculation
				Manager = CalculationRegisters[MetadataObjectName].Recalculations;
			Else
				Raise SubstituteParametersToString(NStr("ru = 'Неизвестный тип объекта метаданных ""%1""'; en = 'Unknown metadata object type: ""%1""'; pl = 'Nieznany typ obiektu metadanych %1';es_ES = 'Tipo del objeto de metadatos desconocido ""%1""';es_CO = 'Tipo del objeto de metadatos desconocido ""%1""';tr = 'Bilinmeyen meta veri nesne türü ""%1""';it = 'Tipo di oggetto metadati sconosciuto: ""%1""';de = 'Unbekannter Metadaten-Objekttyp ""%1""'"), FullName);
			EndIf;
		EndIf;
		
	ElsIf Upper(MOClass) = "BUSINESSPROCESS" Then
		Manager = BusinessProcesses;
		
	ElsIf Upper(MOClass) = "TASK" Then
		Manager = Tasks;
		
	ElsIf Upper(MOClass) = "CONSTANT" Then
		Manager = Constants;
		
	ElsIf Upper(MOClass) = "SEQUENCE" Then
		Manager = Sequences;
	EndIf;
	
	If Manager <> Undefined Then
		Try
			Return Manager[MetadataObjectName];
		Except
			Manager = Undefined;
		EndTry;
	EndIf;
	
	Raise SubstituteParametersToString(NStr("ru = 'Неизвестный тип объекта метаданных ""%1""'; en = 'Unknown metadata object type: ""%1""'; pl = 'Nieznany typ obiektu metadanych %1';es_ES = 'Tipo del objeto de metadatos desconocido ""%1""';es_CO = 'Tipo del objeto de metadatos desconocido ""%1""';tr = 'Bilinmeyen meta veri nesne türü ""%1""';it = 'Tipo di oggetto metadati sconosciuto: ""%1""';de = 'Unbekannter Metadaten-Objekttyp ""%1""'"), FullName);
	
EndFunction

Function EvalExpression(Val Expression, Object, AvailableAttributes)
	
	If Not(TypeOf(Expression) = Type("String") AND StrStartsWith(Expression, "=")) Then
		Return Expression;
	EndIf;
		
	If StrStartsWith(Expression, "'=") Then
		Return Mid(Expression, 2);
	EndIf;
	
	Expression = Mid(Expression, 2);
	
	For Each AttributeDetails In AvailableAttributes Do
		If StrFind(Expression, "[" + AttributeDetails.Presentation + "]") = 0 Then
			Continue;
		EndIf;
		
		Value = "";
		If AttributeDetails.OperationKind = 1 Then
			Value = Object[AttributeDetails.Name];
		Else
			ModulePropertyManager = CommonModule("PropertyManager");
			PropertiesList = New Array;
			PropertiesList.Add(AttributeDetails.Property);
			PropertiesValues = ModulePropertyManager.PropertiesValues(Object.Ref, True, True, PropertiesList);
			For Each TableRow In PropertiesValues.FindRows(New Structure("Property", AttributeDetails.Property)) Do
				Value = TableRow.Value;
			EndDo;
		EndIf;
		
		Expression = StrReplace(Expression, "[" + AttributeDetails.Presentation + "]", """" 
			+ StrReplace(StrReplace(Value, """", """"""), Chars.LF, Chars.LF + "|") + """");
	EndDo;
	
	Return Eval(Expression);
	
EndFunction

Procedure DisableAccessKeysUpdate(Disable, ScheduleUpdate = True)
	
	If Not SSLVersionMatchesRequirements() Then
		Return;
	EndIf;
	
	If SubsystemExists("StandardSubsystems.Users") Then
		ModuleUsers = CommonModule("Users");
		If Not ModuleUsers.IsFullUser() Then
			Return;
		EndIf;
	EndIf;
	
	If SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = CommonModule("AccessManagement");
		ModuleAccessManagement.DisableAccessKeysUpdate(Disable, ScheduleUpdate);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Base-functionality procedures and functions for standalone operation support.

// Returns a flag indicating whether the attribute is a standard attribute.
//
// Parameters:
//  StandardAttributes - StandardAttributeDescriptions - the type and value describe a collection of 
//                                                         settings for various standard attributes.
//  NameAttribute - String - attribute to be checked for being standard;
// 
//  Returns:
//   Boolean.
//
Function IsStandardAttribute(StandardAttributes, AttributeName) Export
	
	For Each Attribute In StandardAttributes Do
		If Attribute.Name = AttributeName Then
			Return True;
		EndIf;
	EndDo;
	Return False;
	
EndFunction

// Returns the name of a kind for a referenced metadata object.
// 
//
// Does not regard business process route points.
//
// Parameters:
//  Reference       - reference to an object - catalog item, document, etc.
//
// Returns:
//  String       - a metadata object kind name, for example, "Catalog" or "Document".
// 
Function ObjectKindByRef(Ref) Export
	
	Return ObjectKindByType(TypeOf(Ref));
	
EndFunction 

// Returns the name of a kind for a metadata object of a specific type.
//
// Does not regard business process route points.
//
// Parameters:
//  Type - an applied object type defined in the configuration.
//
// Returns:
//  String       - a metadata object kind name, for example, "Catalog" or "Document".
// 
Function ObjectKindByType(Type) Export
	
	If Catalogs.AllRefsType().ContainsType(Type) Then
		Return "Catalog";
	
	ElsIf Documents.AllRefsType().ContainsType(Type) Then
		Return "Document";
	
	ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
		Return "BusinessProcess";
	
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCharacteristicTypes";
	
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
		Return "ChartOfAccounts";
	
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCalculationTypes";
	
	ElsIf Tasks.AllRefsType().ContainsType(Type) Then
		Return "Task";
	
	ElsIf ExchangePlans.AllRefsType().ContainsType(Type) Then
		Return "ExchangePlan";
	
	ElsIf Enums.AllRefsType().ContainsType(Type) Then
		Return "Enum";
	
	Else
		Raise SubstituteParametersToString(NStr("ru='Неверный тип значения параметра (%1)'; en = 'Invalid parameter value type (%1)'; pl = 'Nieprawidłowy typ wartości parametru (%1)';es_ES = 'Tipo incorrecto del valor del parámetro (%1)';es_CO = 'Tipo incorrecto del valor del parámetro (%1)';tr = 'Parametre değeri tipi yanlış (%1)';it = 'Tipo di valore parametro non valido (%1)';de = 'Falscher Typ des Parameterwerts (%1)'"), String(Type));
	
	EndIf;
	
EndFunction 

// Checks whether the object is an item group.
//
// Parameters:
//  Object       - Object, Reference, FormDataStructure for the Object type.
//
// Returns:
//  Boolean.
//
Function ObjectIsFolder(Object) Export
	
	If RefTypeValue(Object) Then
		Ref = Object;
	Else
		Ref = Object.Ref;
	EndIf;
	
	ObjectMetadata = Ref.Metadata();
	
	If Metadata.Catalogs.Contains(ObjectMetadata) Then
		
		If NOT ObjectMetadata.Hierarchical
		 OR ObjectMetadata.HierarchyType
		     <> Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
			
			Return False;
		EndIf;
		
	ElsIf NOT Metadata.ChartsOfCharacteristicTypes.Contains(ObjectMetadata) Then
		Return False;
		
	ElsIf NOT ObjectMetadata.Hierarchical Then
		Return False;
	EndIf;
	
	If Ref <> Object Then
		Return Object.IsFolder;
	EndIf;
	
	Return ObjectAttributeValue(Ref, "IsFolder");
	
EndFunction

// Checks whether the value is a reference type value.
//
// Parameters:
//  Value       - Object reference - catalog item, document, etc.
//
// Returns:
//  Boolean - True if the value is a reference type value.
//
Function RefTypeValue(Value) Export
	
	If Value = Undefined Then
		Return False;
	EndIf;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Documents.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Enums.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfCharacteristicTypes.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfAccounts.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfCalculationTypes.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If BusinessProcesses.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If BusinessProcesses.RoutePointsAllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Tasks.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ExchangePlans.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Returns a structure containing attribute values retrieved from the infobase using the object 
// reference.
// 
//  If access to any of the attributes is denied, an exception is raised.
//  To read attribute values regardless of current user rights, enable privileged mode.
//  
// 
// Parameters:
//  Reference       - Reference to an object - catalog item, document, etc.
//
//  Attributes - String - attribute names separated with commas, formatted according to structure 
//              requirements.
//              Example: "Code, Description, Parent".
//            - Structure - FixedStructure - keys are field aliases used for resulting structure 
//              keys, values (optional) are field names.
//              
//              If a value is empty, it is considered equal to the key.
//            - Array - FixedArray - attribute names formatted according to structure property 
//              requirements.
//
// Returns:
//  Structure - contains names (keys) and values of the requested attributes.
//              If the string of the requested attributes is empty, an empty structure is returned.
//
Function ObjectAttributesValues(Ref, Val Attributes) Export
	
	If TypeOf(Attributes) = Type("String") Then
		If IsBlankString(Attributes) Then
			Return New Structure;
		EndIf;
		Attributes = StrSplit(Attributes, ",", False);
	EndIf;
	
	AttributesStructure = New Structure;
	If TypeOf(Attributes) = Type("Structure") Or TypeOf(Attributes) = Type("FixedStructure") Then
		AttributesStructure = Attributes;
	ElsIf TypeOf(Attributes) = Type("Array") Or TypeOf(Attributes) = Type("FixedArray") Then
		For Each Attribute In Attributes Do
			AttributesStructure.Insert(StrReplace(Attribute, ".", ""), Attribute);
		EndDo;
	Else
		Raise SubstituteParametersToString(NStr("ru = 'Неверный тип второго параметра Реквизиты: %1'; en = 'Invalid Attributes parameter type: %1'; pl = 'Nieprawidłowy typ parametru Atrybuty: %1';es_ES = 'Tipo del parámetro de Atributos inválido: %1';es_CO = 'Tipo del parámetro de Atributos inválido: %1';tr = 'Geçersiz Özellikler parametresinin türü: %1';it = 'Attributi non valido tipo di parametro: %1';de = 'Ungültiger Parametertyp für Attribute: %1'"), String(TypeOf(Attributes)));
	EndIf;
	
	FieldTexts = "";
	For Each KeyAndValue In AttributesStructure Do
		FieldName   = ?(ValueIsFilled(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Key));
		
		Alias = TrimAll(KeyAndValue.Key);
		
		FieldTexts  = FieldTexts + ?(IsBlankString(FieldTexts), "", ",") + "
		|	" + FieldName + " AS " + Alias;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	|" + FieldTexts + "
	|FROM
	|	" + Ref.Metadata().FullName() + " AS SpecifiedTableAlias
	|WHERE
	|	SpecifiedTableAlias.Ref = &Ref
	|";
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Result = New Structure;
	For Each KeyAndValue In AttributesStructure Do
		Result.Insert(KeyAndValue.Key);
	EndDo;
	FillPropertyValues(Result, Selection);
	
	Return Result;
	
EndFunction

// Returns an attribute value retrieved from the infobase using the object reference.
// 
//  If access to the attribute is denied, an exception is raised.
//  To read attribute values regardless of current user rights, enable privileged mode.
//  
// 
// Parameters:
//  Reference       - reference to an object - catalog item, document, etc.
//  NameAttribute - String - e.g.  "Code".
// 
// Returns:
//  Arbitrary - depends on the type of the read attribute.
// 
Function ObjectAttributeValue(Ref, AttributeName) Export
	
	Result = ObjectAttributesValues(Ref, AttributeName);
	Return Result[StrReplace(AttributeName, ".", "")];
	
EndFunction 

// Returns True if a susbystem exists.
//
// Parameters:
//  FullSubsystemName - String. Full name for the subsystem metadata object, excluding the "Susbystem." substring.
//                        Example: "StandardSubsystems.Core".
//
// Example of calling an optional subsystem:
//
//  If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
//  	ModuleAccessManagement = Common.CommonModule("AccessManagement");
//  	ModuleAccessManagement.<Method name>();
//  EndIf
//
// Returns:
//  Boolean.
//
Function SubsystemExists(FullSubsystemName) Export
	
	SubsystemNames = SubsystemNames();
	Return SubsystemNames.Get(FullSubsystemName) <> Undefined;
	
EndFunction

// Returns a map between subsystem names and the True value;
Function SubsystemNames() Export
	
	Return New FixedMap(SubordinateSubsystemsNames(Metadata));
	
EndFunction

Function SubordinateSubsystemsNames(ParentSubsystem)
	
	Names = New Map;
	
	For Each CurrentSubsystem In ParentSubsystem.Subsystems Do
		
		Names.Insert(CurrentSubsystem.Name, True);
		SubordinateItemNames = SubordinateSubsystemsNames(CurrentSubsystem);
		
		For each SubordinateItemName In SubordinateItemNames Do
			Names.Insert(CurrentSubsystem.Name + "." + SubordinateItemName.Key, True);
		EndDo;
	EndDo;
	
	Return Names;
	
EndFunction

// Returns a reference to the common module by the name.
//
// Parameters:
//  Name          - String - common module name, for example:
//                 "Common",
//                 "CommonClient".
//
// Returns:
//  CommonModule.
//
Function CommonModule(Name) Export
	
	If Metadata.CommonModules.Find(Name) <> Undefined Then
		Module = Eval(Name);
	Else
		Module = Undefined;
	EndIf;
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise SubstituteParametersToString(NStr("ru = 'Общий модуль ""%1"" не найден.'; en = 'Common module ""%1"" is not found.'; pl = 'Nie znaleziono wspólnego modułu ""%1"".';es_ES = 'Módulo común ""%1"" no se ha encontrado.';es_CO = 'Módulo común ""%1"" no se ha encontrado.';tr = 'Ortak modül ""%1"" bulunamadı.';it = 'Il modulo comune""%1"" non è stato trovato.';de = 'Gemeinsames Modul ""%1"" wurde nicht gefunden.'"), Name);
	EndIf;
	
	Return Module;
	
EndFunction

Function SubstituteParametersToString(Val SubstitutionString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	SubstitutionString = StrReplace(SubstitutionString, "%1", Parameter1);
	SubstitutionString = StrReplace(SubstitutionString, "%2", Parameter2);
	SubstitutionString = StrReplace(SubstitutionString, "%3", Parameter3);
	
	Return SubstitutionString;
EndFunction

// Executes an arbitrary algorithm in the 1C:Enterprise script, setting the safe mode of script 
//  execution and the safe mode of data separation for all separators of the configuration.
//   As the result, when the algorithm is being executed:
//   - attempts to set the privileged mode are ignored;
//   - all external (relative to the 1C:Enterprise platform) actions (COM, add-in loading, external 
//       application startup, operating system command execution, file system and Internet resource 
//       access) are prohibited;
//   - session separators cannot be disabled;
//   - session separator values cannot be changed (if data separation is not disabled 
//       conditionally);
//   - objects that manage the conditional separation state cannot be changed.
//
// Parameters:
//  Algorithm - String - containing an arbitrary algorithm in the 1C:Enterprise language.
//  Parameters - Arbitrary - any value as might be required for the algorithm. The algorithm code 
//    must refer to this value as the Parameters variable.
//    
//
Procedure ExecuteInSafeMode(Val Algorithm, Val Parameters = Undefined) Export
	
	SetSafeMode(True);
	
	SeparatorArray = ApplicationSeparators();
	
	For Each SeparatorName In SeparatorArray Do
		
		SetDataSeparationSafeMode(SeparatorName, True);
		
	EndDo;
	
	Execute Algorithm;
	
EndProcedure

// Returns an array of the separators that are in the configuration.
//
// Returns FixedArray(String) - an array of common attribute names used as separators.
//  
//
Function ApplicationSeparators() Export
	
	SeparatorArray = New Array;
	
	For Each CommonAttribute In Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			SeparatorArray.Add(CommonAttribute.Name);
		EndIf;
	EndDo;
	
	Return New FixedArray(SeparatorArray);
	
EndFunction

#EndRegion

#EndIf