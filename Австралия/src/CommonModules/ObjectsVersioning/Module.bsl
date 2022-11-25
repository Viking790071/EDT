#Region Public

// Executed on configuration update.
// 1. Clears versioning settings for objects that cannot be versioned.
// 2. Enables the default versioning settings.
//
Procedure UpdateObjectVersioningSettings() Export
	
	VersionedObjects = GetVersionedObjects();
	
	RecordSelection = InformationRegisters.ObjectVersioningSettings.Select();
	While RecordSelection.Next() Do
		If VersionedObjects.Find(RecordSelection.ObjectType) = Undefined Then
			RecordManager = RecordSelection.GetRecordManager();
			RecordManager.Delete();
		EndIf;
	EndDo;
	
	VersionedObjectsVT = New ValueTable;
	VersionedObjectsVT.Columns.Add("ObjectType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	For Each ObjectType In VersionedObjects Do
		VersionedObjectsVT.Add();
	EndDo;
	VersionedObjectsVT.LoadColumn(VersionedObjects, "ObjectType");
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	VersionedObjects.ObjectType
	|INTO VersionedObjectsTable
	|FROM
	|	&VersionedObjects AS VersionedObjects
	|;
	|////////////////////////////////////////////////////////////
	|SELECT
	|	VersionedObjectsTable.ObjectType
	|FROM
	|	VersionedObjectsTable AS VersionedObjectsTable
	|		LEFT JOIN InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings
	|			ON ObjectVersioningSettings.ObjectType = VersionedObjectsTable.ObjectType
	|WHERE
	|	ObjectVersioningSettings.Variant IS NULL ";
			
	Query.Parameters.Insert("VersionedObjects", VersionedObjectsVT);
	VersionedObjectsNoSettings = Query.Execute().Unload().UnloadColumn("ObjectType");
	
	SettingRecordSet = InformationRegisters.ObjectVersioningSettings.CreateRecordSet();
	SettingRecordSet.Read();
	For Each VersionedObject In VersionedObjectsNoSettings Do
		NewRecord = SettingRecordSet.Add();
		NewRecord.ObjectType = VersionedObject;
		NewRecord.Variant = Enums.ObjectsVersioningOptions.DontVersionize;
	EndDo;
	
	SettingRecordSet.Write(True);
	
EndProcedure

// Saves the object versioning setting.
//
// Parameters:
//  ObjectType - String, Type, MetadataObject, CatalogRef.MetadataObjectIDs - metadata object;
//  VersioningMode - EnumRef.ObjectVersioningModes - version recording condition;
//  VersionLifetime - EnumRef.VersionLifetimes - period after which versions must be deleted.
//
Procedure SaveObjectVersioningConfiguration(Val ObjectType, Val VersioningMode, Val VersionLifetime = Undefined) Export
	
	If TypeOf(ObjectType) <> Type("CatalogRef.MetadataObjectIDs") Then
		ObjectType = Common.MetadataObjectID(ObjectType);
	EndIf;
	
	Setting = InformationRegisters.ObjectVersioningSettings.CreateRecordManager();
	Setting.ObjectType = ObjectType;
	
	If VersionLifetime = Undefined Then
		Setting.Read();
		If Setting.Selected() Then
			VersionLifetime = Setting.VersionsLifetime;
		Else
			Setting.ObjectType = ObjectType;
			VersionLifetime = Enums.VersionsLifetimes.Indefinitely;
		EndIf;
	EndIf;
	
	Setting.VersionsLifetime = VersionLifetime;
	Setting.Variant = VersioningMode;
	Setting.Write();
	
EndProcedure

// Configures forms before enabling the versioning subsystem.
//
// Parameters:
//  Form - ClientApplicationForm - form used to enable the versioning mechanism.
//
Procedure OnCreateAtServer(Form) Export
	
	FullMetadataName = Undefined;
	If HasRightToReadObjectVersionData() AND GetFunctionalOption("UseObjectsVersioning") Then
		FormNameArray = StrSplit(Form.FormName, ".", False);
		FullMetadataName = FormNameArray[0] + "." + FormNameArray[1];
	EndIf;
	
	Object = Undefined;
	If FullMetadataName <> Undefined Then
		Object = Common.MetadataObjectID(FullMetadataName);
	EndIf;
	
	Form.SetFormFunctionalOptionParameters(New Structure("VersionizedObjectType", Object));
	
EndProcedure

// Returns a flag that shows that versioning is used for the specified metadata object.
//
// Parameters:
//  ObjectName - String - full path to metadata object. For example, "Catalog.Products".
//
// Returns:
//  Boolean - True, if enabled.
//
Function ObjectVersioningEnabled(ObjectName) Export
	ObjectsList = CommonClientServer.ValueInArray(ObjectName);
	Return ObjectVersioningIsEnabled(ObjectsList)[ObjectName];
EndFunction

// Returns a flag indicating that versioning is used for the list of objects.
//
// Parameters:
//  ListOfObjects - Array - list of metadata object names.
//
// Returns:
//  Map - check result:
//   * Key - String - metadata object name.
//   * Value - Boolean - versioning is enabled or disabled.
//
Function ObjectVersioningIsEnabled(ObjectsList) Export
	
	MapTypes = Common.MetadataObjectIDs(ObjectsList);
	ObjectsTypes = New Array;
	For Each Item In MapTypes Do
		ObjectsTypes.Add(Item.Value);
	EndDo;
	
	QueryText =
	"SELECT
	|	MetadataObjectIDs.FullName AS ObjectName,
	|	ISNULL(ObjectVersioningSettings.Use, FALSE) AS VersioningEnabled
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|		LEFT JOIN InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings
	|		ON ObjectVersioningSettings.ObjectType = MetadataObjectIDs.Ref
	|WHERE
	|	MetadataObjectIDs.Ref IN(&ObjectsTypes)";
	
	Query = New Query(QueryText);
	Query.SetParameter("ObjectsTypes", ObjectsTypes);
	
	Result = New Map;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Result.Insert(Selection.ObjectName, Selection.VersioningEnabled);
	EndDo;
	
	Return Result;
	
EndFunction

// Enables versioning for the specified metadata object.
//
// Parameters:
//  ObjectName - String - full path to metadata object. For example, "Catalog.Products".
//  VersioningMode - EnumRef.ObjectVersioningModes - object versioning mode.
//
Procedure EnableObjectVersioning(ObjectName, Val VersioningMode = Undefined) Export
	
	If VersioningMode = Undefined Then
		VersioningMode = Enums.ObjectsVersioningOptions.VersionizeOnWrite;
	EndIf;
	
	If TypeOf(VersioningMode) = Type("String") Then
		If Metadata.Enums.ObjectsVersioningOptions.EnumValues.Find(VersioningMode) <> Undefined Then
			VersioningMode = Enums.ObjectsVersioningOptions[VersioningMode];
		EndIf;
	EndIf;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Неизвестный вариант версионирования: ""%1""'; en = 'Unknown versioning option: ""%1""'; pl = 'Nieznany wariant wersjonowania: ""%1""';es_ES = 'Variante desconocido de versionar: ""%1""';es_CO = 'Variante desconocido de versionar: ""%1""';tr = 'Bilinmeyen sürüm seçeneği: ""%1""';it = 'Opzione di versioning non conosciuta: ""%1""';de = 'Unbekannte Version der Versionsverwaltung: ""%1""'"), VersioningMode);
	CommonClientServer.Validate(TypeOf(VersioningMode) = Type("EnumRef.ObjectsVersioningOptions"),
		ErrorText, "ObjectsVersioning.EnableObjectVersioning");
		
	If Not ObjectVersioningEnabled(ObjectName) Then
		SaveObjectVersioningConfiguration(ObjectName, VersioningMode);
	EndIf;
	
EndProcedure

// Enables versioning for specified metadata objects.
//
// Parameters:
//  Objects - Map - objects for which versioning must be enabled:
//   * Key    - String - full path to metadata object. For example, "Catalog.Products".
//   * Value - EnumRef.ObjectVersioningModes - object versioning mode.
//
Procedure EnableObjectsVersioning(Objects) Export
	
	For Each Object In Objects Do
		EnableObjectVersioning(Object);
	EndDo;
	
EndProcedure

#EndRegion

#Region Internal

// Fills empty attributes for the version information register.
Procedure UpdateObjectsVersionsInformation(Parameters) Export
	
	QueryText =
	"SELECT TOP 10000
	|	ObjectsVersions.Object,
	|	ObjectsVersions.VersionNumber
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.DataSize = 0";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	
	ProcessedRecords = 0;
	While Selection.Next() Do
		RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
		RecordSet.Filter.Object.Set(Selection.Object);
		RecordSet.Filter.VersionNumber.Set(Selection.VersionNumber);
		RecordSet.Read();
		Try
			RecordSet.Write();
			ProcessedRecords = ProcessedRecords + 1;
		Except
			WriteLogEvent(
				NStr("ru = 'Версионирование'; en = 'Versioning'; pl = 'Zarządzanie wersjami';es_ES = 'Versionando';es_CO = 'Versionando';tr = 'Sürüm belirleme';it = 'Versionamento';de = 'Versionierung'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error, RecordSet.Metadata(),
				,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не удалось обновить сведения о версии №%1 объекта ""%2"" по причине:
					|%3'; 
					|en = 'Cannot update information on version No. %1 of object ""%2"" due to:
					|%3'; 
					|pl = 'Nie udało się zaktualizować infomacje o wersji nr. %1 obiektu ""%2"" z powodu:
					|%3';
					|es_ES = 'No se ha podido actualizar la información de la versión №%1 del objeto ""%2"" a causa de:
					|%3';
					|es_CO = 'No se ha podido actualizar la información de la versión №%1 del objeto ""%2"" a causa de:
					|%3';
					|tr = '""%1"" Nesnenin %2sürüm numarasına ilişkin bilgiler 
					|%3 nedeniyle güncellenemedi';
					|it = 'Impossibile aggiornare le informazioni sulla versione N° %1 dell''oggetto ""%2"" a causa di:
					|%3';
					|de = 'Es war nicht möglich, die Versionsnummer %1 des Objekts ""%2"" zu aktualisieren, da:
					|%3'", CommonClientServer.DefaultLanguageCode()),
					Selection.VersionNumber,
					Common.SubjectString(Selection.Object),
					DetailErrorDescription(ErrorInfo())));
		EndTry;
	EndDo;
	
	If Selection.Count() > 0 Then
		If ProcessedRecords = 0 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Процедуре UpdateObjectVersionInformation не удалось обработать некоторые записи регистра сведений ObjectVersions (пропущены): %1'; en = 'UpdateObjectVersionInformation procedure was unable to process some records from the ObjectVersions register: %1'; pl = 'ProcedurzeUpdateObjectVersionInformation nie udało się przetworzyć niektóre wpisy ObjectVersions rejestru informacji: %1';es_ES = 'El procedimiento UpdateObjectVersionInformation no ha podido procesar algunos registros del registro de información ObjectVersions: %1';es_CO = 'El procedimiento UpdateObjectVersionInformation no ha podido procesar algunos registros del registro de información ObjectVersions: %1';tr = 'UpdateObjectVersionInformation işlemi ObjectVersions kayıt günlüğün bazı kayıtlarını işleyemedi (atlattı): %1';it = 'La procedura UpdateObjectVersionInformation non è stata in grado di processare alcune registrazioni dal registro ObjectVersions: %1';de = 'Die Prozedur UpdateObjectVersionInformation konnte einige Informationsregistersätze der ObjectVersions nicht verarbeiten (weggelassen): %1'"), 
					Selection.Count());
			Raise MessageText;
		EndIf;
		Parameters.ProcessingCompleted = False;
	EndIf;
	
EndProcedure

// Writes an object version to the infobase.
//
// Parameters:
//  Source - CatalogObject, DocumentObject, and other objects - infobase object to be written;
//  WriteMode - DocumentWriteMode.
//
Procedure WriteObjectVersion(Val Source, WriteMode = Undefined) Export
	
	// Unconditional DataExchange.Load verification is not required because while writing the versioned 
	// object during the exchange it is necessary to save its current version in the version history.
	If Not GetFunctionalOption("UseObjectsVersioning") Then
		Return;
	EndIf;
	
	If Common.RefTypeValue(Source) Then
		Source = Source.GetObject();
	EndIf;
	
	If Source = Undefined Then
		Return;
	EndIf;
	
	If Source.DataExchange.Load
		AND Source.AdditionalProperties.Property("SkipObjectVersionRecord")
		AND PrivilegedMode() Then
		Return;
	EndIf;
	
	If StandardSubsystemsServer.IsMetadataObjectID(Source) Then
		Return;
	EndIf;
	
	If Source.DataExchange.Load Then
		If Not Source.Ref.IsEmpty() Then
			WriteCurrentVersionData(Source.Ref, True);
		EndIf;
		Return;
	EndIf;
	
	If ObjectWritingInProgress() Then
		Return;
	EndIf;
	
	If Source.AdditionalProperties.Property("ObjectVersionInfo") Then
		Return;
	EndIf;
	
	OnCreateObjectVersion(Source, WriteMode);
	
EndProcedure

// Writes a version of the object received during the data exchange to the infobase.
//
// Parameters:
//  Object - Object - object to be written.
//  ObjectVersionInfo - Structure - contains object version information.
//  RefExists - Boolean - flag specifying whether the referenced object exists in the infobase.
Procedure CreateObjectVersionByDataExchange(Object, ObjectVersionInfo, RefExists, Sender) Export
	
	Ref = Object.Ref;
	
	If Not ValueIsFilled(RefExists) Then
		RefExists = Common.RefExists(Ref);
	EndIf;
	
	ObjectVersionType = Enums.ObjectVersionTypes[ObjectVersionInfo.ObjectVersionType];
	
	LastVersionNumber = 0;
	If RefExists Then
		If ObjectIsVersioned(Ref, LastVersionNumber) AND VersionRegisterIsIncludedInExchangePlan(Sender) Then
			Return;
		EndIf;
	Else
		Ref = Common.ObjectManagerByRef(Ref).GetRef(Object.GetNewObjectRef().UUID());
	EndIf;
	
	ObjectVersionInfo.Insert("Object", Ref);
	ObjectVersionInfo.Insert("VersionNumber", Number(LastVersionNumber) + 1);
	ObjectVersionInfo.ObjectVersionType = ObjectVersionType;
	
	If Not ValueIsFilled(ObjectVersionInfo.VersionAuthor) Then
		ObjectVersionInfo.VersionAuthor = Users.AuthorizedUser();
	EndIf;
	
	CreateObjectVersion(Object, ObjectVersionInfo, False);
	
EndProcedure

// Sets the object version ignoring flag.
//
// Parameters:
//	Reference - Reference to the ignored object.
//	VersionNumber - Number - Version number of the ignored object.
//	Ignore - Boolean Version ignoring flag.
//
Procedure IgnoreObjectVersion(Ref, VersionNumber, Ignore) Export
	
	CheckObjectEditRights(Ref.Metadata());
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
	RecordSet.Filter.Object.Set(Ref);
	RecordSet.Filter.VersionNumber.Set(VersionNumber);
	RecordSet.Read();
	
	Record = RecordSet[0];
	
	Record.VersionIgnored = Ignore;
	
	RecordSet.Write();
	
EndProcedure

// Returns the number of conflicts and rejected objects.
//
// Parameters:
//	ExchangeNodes - ExchangePlanRef, Array, ListOfValues, Undefined - filter used to display the number of conflicts.
//	IsConflictCount - Boolean - If True, returns the number of conflicts. If False, returns the number of rejected objects.
//	ShowIgnoredItems - Boolean - indicates whether ignored objects are included.
//	InfobaseNode - ExchangePlanRef - Total count for a specific node.
//	Period - Standard period - Total count for a specific period.
//	SearchString - String - Number of objects that contain SearchString in their comments.
//
Function ConflictOrRejectedItemCount(ExchangeNodes, IsConflictCount,
	ShowIgnoredItems, Period, SearchString) Export
	
	Count = 0;
	
	If Not HasRightToReadObjectVersionInfo() Then
		Return Count;
	EndIf;
	
	QueryText = "SELECT ALLOWED
	|	COUNT(ObjectsVersions.Object) AS Count
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.VersionIgnored <> &FilterBySkipped
	|	AND (ObjectsVersions.ObjectVersionType IN (&VersionTypes))
	|	[FilterByNode]
	|	[FilterByPeriod]
	|	[FilterByReason]";
	
	Query = New Query;
	
	FilterBySkipped = ?(ShowIgnoredItems, Undefined, True);
	Query.SetParameter("FilterBySkipped", FilterBySkipped);
	
	If ExchangeNodes = Undefined Then
		FIlterRow = "";
	ElsIf ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodes)) Then
		FIlterRow = "AND ObjectsVersions.VersionAuthor = &ExchangeNodes";
		Query.SetParameter("ExchangeNodes", ExchangeNodes);
	Else
		FIlterRow = "AND ObjectsVersions.VersionAuthor IN (&ExchangeNodes)";
		Query.SetParameter("ExchangeNodes", ExchangeNodes);
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByNode]", FIlterRow);
	
	If ValueIsFilled(Period) Then
		
		FIlterRow = "AND (ObjectsVersions.VersionDate >= &StartDate
		| AND ObjectsVersions.VersionDate <= &EndDate)";
		Query.SetParameter("StartDate", Period.StartDate);
		Query.SetParameter("EndDate", Period.EndDate);
		
	Else
		
		FIlterRow = "";
		
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByPeriod]", FIlterRow);
	
	VersionTypes = New ValueList;
	If ValueIsFilled(IsConflictCount) Then
		
		If IsConflictCount Then
			
			VersionTypes.Add(Enums.ObjectVersionTypes.ConflictDataAccepted);
			VersionTypes.Add(Enums.ObjectVersionTypes.NotAcceptedCollisionData);
			
			FIlterRow = "";
			
		Else
			
			VersionTypes.Add(Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase);
			VersionTypes.Add(Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase);
			
			If ValueIsFilled(SearchString) Then
				
				FIlterRow = "AND ObjectsVersions.Comment LIKE &Comment";
				Query.SetParameter("Comment", "%" + SearchString + "%");
				
			Else
				
				FIlterRow = "";
				
			EndIf;
			
		EndIf;
		
	Else // Filtering by comment is not supported.
		
		VersionTypes.Add(Enums.ObjectVersionTypes.ConflictDataAccepted);
		VersionTypes.Add(Enums.ObjectVersionTypes.NotAcceptedCollisionData);
		VersionTypes.Add(Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase);
		VersionTypes.Add(Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase);
		
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByReason]", FIlterRow);
	Query.SetParameter("VersionTypes", VersionTypes);
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		Count = Selection.Count;
	EndIf;
	
	Return Count;
	
EndFunction

Procedure MoveVersioningSettings() Export
	
	QueryText = 
	"SELECT
	|	DeleteObjectVersioningSettings.ObjectType AS ObjectName,
	|	DeleteObjectVersioningSettings.Variant,
	|	DeleteObjectVersioningSettings.VersionsLifetime
	|FROM
	|	InformationRegister.DeleteObjectVersioningSettings AS DeleteObjectVersioningSettings";

	Query = New Query;
	Query.Text = QueryText;
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	VersioningSettings = QueryResult.Unload();
	
	RecordSet = InformationRegisters.ObjectVersioningSettings.CreateRecordSet();
	For Each VersioningSetting In VersioningSettings Do
		MetadataObject = Metadata.FindByFullName(VersioningSetting.ObjectName);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		ObjectType = Common.MetadataObjectID(MetadataObject);
		
		Record = RecordSet.Add();
		FillPropertyValues(Record, VersioningSetting);
		Record.ObjectType = ObjectType;
	EndDo;
	InfobaseUpdate.WriteData(RecordSet);
	
	RecordSet = InformationRegisters.DeleteObjectVersioningSettings.CreateRecordSet();
	InfobaseUpdate.WriteData(RecordSet);
	
EndProcedure

Function HasRightToReadObjectVersionInfo() Export
	Return AccessRight("View", Metadata.InformationRegisters.ObjectsVersions);
EndFunction

Function HasRightToReadObjectVersionData() Export
	Return AccessRight("View", Metadata.CommonCommands.ChangeHistory);
EndFunction

// Fills parameters of a dynamic list that displays corrupted object versions generated while 
// getting data as a result of data exchange in case of conflicts or if writing documents was 
// canceled due to change closing date check failure.
//
// Parameters:
//	List - DynamicList - dynamic list to be initialized.
//	IssueKind - String - Conflicts - list of conflicts is initialized,
//                         DeclinedDueToDate - declined due to date.
//
Procedure InitializeDynamicListOfCorruptedVersions(List, IssueKind = "Conflicts") Export
	
	If IssueKind = "RejectedDueToDate" Then
		QueryText =
		"SELECT ALLOWED
		|	UnacceptedVersion.VersionDate AS Date,
		|	UnacceptedVersion.Object AS Ref,
		|	UnacceptedVersion.Comment AS ProhibitionReason,
		|	CASE
		|		WHEN UnacceptedVersion.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase)
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS NewObject,
		|	ISNULL(UnacceptedVersion.VersionNumber, 0) AS OtherVersionNumber,
		|	UnacceptedVersion.VersionAuthor AS OtherVersionAuthor,
		|	ISNULL(CurrentVersion.VersionNumber, 0) AS ThisVersionNumber,
		|	VALUETYPE(UnacceptedVersion.Object) AS TypeString,
		|	UnacceptedVersion.VersionIgnored AS VersionIgnored
		|FROM
		|	InformationRegister.ObjectsVersions AS UnacceptedVersion
		|		LEFT JOIN InformationRegister.ObjectsVersions AS CurrentVersion
		|		ON UnacceptedVersion.Object = CurrentVersion.Object
		|			AND (UnacceptedVersion.VersionNumber = CurrentVersion.VersionNumber + 1)
		|WHERE
		|	UnacceptedVersion.ObjectVersionType IN (VALUE(Enum.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase),
		|		VALUE(Enum.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase))";
		
	ElsIf IssueKind = "Conflicts" Then
		QueryText =
		"SELECT ALLOWED
		|	OtherApplicationVersions.VersionDate AS Date,
		|	OtherApplicationVersions.Object AS Ref,
		|	VALUETYPE(OtherApplicationVersions.Object) AS TypeString,
		|	ThisApplicationVersions.VersionNumber AS ThisVersionNumber,
		|	OtherApplicationVersions.VersionNumber AS OtherVersionNumber,
		|	OtherApplicationVersions.VersionAuthor AS OtherVersionAuthor,
		|	CASE
		|		WHEN OtherApplicationVersions.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.ConflictDataAccepted)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS OtherVersionAccepted,
		|	OtherApplicationVersions.VersionIgnored AS VersionIgnored
		|FROM
		|	InformationRegister.ObjectsVersions AS OtherApplicationVersions
		|		LEFT JOIN InformationRegister.ObjectsVersions AS ThisApplicationVersions
		|		ON OtherApplicationVersions.Object = ThisApplicationVersions.Object
		|			AND (OtherApplicationVersions.VersionNumber = ThisApplicationVersions.VersionNumber + 1)
		|WHERE
		|	OtherApplicationVersions.ObjectVersionType IN (VALUE(Enum.ObjectVersionTypes.ConflictDataAccepted),
		|		VALUE(Enum.ObjectVersionTypes.NotAcceptedCollisionData))";
	EndIf;
	
	List.QueryText = QueryText;
	List.CustomQuery = True;
	List.MainTable = "InformationRegister.ObjectsVersions";
	List.DynamicDataRead = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddRefsSearchExceptions. 
Procedure OnAddReferenceSearchExceptions(Array) Export
	
	Array.Add(Metadata.InformationRegisters.ObjectsVersions.FullName());
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromSlave. 
Procedure OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender) Export
	
	If TypeOf(DataItem) = Type("InformationRegisterRecordSet.ObjectsVersions") AND DataItem.Count() > 0 Then
		ReadInfoAboutNode(DataItem[0]);
		
		Object = DataItem.Filter.Object.Value;
		NumberOfUnsynchronizedVersions = NumberOfUnsynchronizedVersions(Object);
		VersionNumber = DataItem.Filter.VersionNumber.Value - DataItem[0].BeforeAfter + NumberOfUnsynchronizedVersions;
		DataItem[0].VersionOwner = DataItem[0].VersionOwner - DataItem[0].BeforeAfter + NumberOfUnsynchronizedVersions;
		
		RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
		RecordSet.Filter.Object.Set(DataItem.Filter.Object.Value);
		RecordSet.Filter.VersionNumber.Set(VersionNumber);
		RecordSet.Read();
		
		If Common.ValueToXMLString(DataItem) = Common.ValueToXMLString(RecordSet) Then
			// Consider that there are no conflicts.
			GetItem = DataItemReceive.Ignore;
			Return;
		EndIf;
		
		HasConflict = ExchangePlans.IsChangeRecorded(Sender.Ref, Object);
		
		ObjectVersionType = Enums.ObjectVersionTypes.NotAcceptedCollisionData;
		If Sender.AdditionalProperties.Property("RejectedDueToPeriodEndClosingDate")
			AND Sender.AdditionalProperties.RejectedDueToPeriodEndClosingDate[Object] <> Undefined Then
				HasConflict = True;
				If Sender.AdditionalProperties.RejectedDueToPeriodEndClosingDate[Object] = "RejectedDueToPeriodEndClosingDateObjectExistsInInfobase" Then
					ObjectVersionType = Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase;
				Else
					ObjectVersionType = Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase;
				EndIf;
		EndIf;
		
		If Not HasConflict Then
			// If the object was not changed, the version is overwritten without check because if the object was 
			// changed in the sender node is unknown.
			
			If RecordSet.Count() = 0 Then
				Record = RecordSet.Add();
				Record.Object = Object;
				Record.VersionNumber = VersionNumber;
			Else
				Record = RecordSet[0];
			EndIf;
			FillPropertyValues(Record, DataItem[0], , "Object,VersionNumber");
			Record.VersionNumber = VersionNumber;
			RecordSet.Write();
			ExchangePlans.DeleteChangeRecords(Sender.Ref, RecordSet);
			
			GetItem = DataItemReceive.Ignore;
			Return;
		EndIf;
		
		If ObjectVersionType = Enums.ObjectVersionTypes.NotAcceptedCollisionData Then
			VersionsToExport = VersionsToExport(Object, Sender.Ref);
			If VersionsToExport.Count() = 0 Then 
				Return;
			EndIf;
			MinimalVersionNumber = VersionsToExport[0].VersionNumber;
			For Counter = 1 To VersionsToExport.Count() - 1 Do
				If VersionsToExport[Counter - 1].VersionNumber - VersionsToExport[Counter].VersionNumber = 1 Then
					MinimalVersionNumber = Min(MinimalVersionNumber, VersionsToExport[Counter].VersionNumber);
				Else
					Break;
				EndIf;
			EndDo;
			
			If MinimalVersionNumber > VersionNumber Then
				Return;
			EndIf;
		EndIf;
			
		ObjectVersionConflicts = New Map;
		If Sender.AdditionalProperties.Property("ObjectVersionConflicts") Then
			ObjectVersionConflicts = Sender.AdditionalProperties.ObjectVersionConflicts;
		Else
			Sender.AdditionalProperties.Insert("ObjectVersionConflicts", ObjectVersionConflicts);
		EndIf;
		
		ConflictVersionNumber = ObjectVersionConflicts[Object];
		LastVersionNumber = LastVersionNumber(Object);
		UpdateConflictVersion = True;
		If ConflictVersionNumber = Undefined Then
			ConflictVersionNumber = LastVersionNumber + 1;
			
			RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
			RecordSet.Filter.Object.Set(Object);
			RecordSet.Filter.VersionNumber.Set(ConflictVersionNumber);
			Record = RecordSet.Add();
			FillPropertyValues(Record, DataItem[0]);
			Record.VersionNumber = ConflictVersionNumber;
			Record.ObjectVersionType = ObjectVersionType;
			Record.VersionDate = CurrentSessionDate();
			Record.VersionAuthor = Sender.Ref;
			Record.Node = Common.SubjectString(Record.VersionAuthor);
			Record.Comment = NStr("ru = 'Отклоненная версия (автоматическое разрешение конфликта).'; en = 'The rejected version (automatic conflict resolving).'; pl = 'Odrzucona wersja (automatyczne rozwiązywanie konfliktów).';es_ES = 'Versión denegada (resolución automática del conflicto).';es_CO = 'Versión denegada (resolución automática del conflicto).';tr = 'Reddedilen sürüm (otomatik çakışma çözümü).';it = 'La versione rifiutata (risoluzione automatica di conflitto).';de = 'Abgelehnte Version (automatische Konfliktlösung).'");
			RecordSet.Write();
			LastVersionNumber = ConflictVersionNumber;
			ObjectVersionConflicts.Insert(Object, ConflictVersionNumber);
			UpdateConflictVersion = False;
		EndIf;
		RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
		RecordSet.Filter.Object.Set(Object);
		RecordSet.Filter.VersionNumber.Set(LastVersionNumber + 1);
		Record = RecordSet.Add();
		FillPropertyValues(Record, DataItem[0]);
		Record.VersionNumber = LastVersionNumber + 1;
		Record.VersionOwner = ConflictVersionNumber;
		Record.ObjectVersionType = ObjectVersionType;
		RecordSet.Write();
		
		If UpdateConflictVersion Then
			RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
			RecordSet.Filter.Object.Set(Object);
			RecordSet.Filter.VersionNumber.Set(ConflictVersionNumber);
			RecordSet.Read();
			For Each Record In RecordSet Do
				Record.Checksum = DataItem[0].Checksum;
				Record.ObjectVersion = DataItem[0].ObjectVersion;
				Record.DataSize = DataItem[0].DataSize;
				Record.HasVersionData = DataItem[0].HasVersionData;
			EndDo;
			RecordSet.Write();
		EndIf;
		
		GetItem = DataItemReceive.Ignore;
	EndIf;
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromMaster. 
Procedure OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender) Export
	
	If Sender = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(DataItem) = Type("InformationRegisterRecordSet.ObjectsVersions") AND DataItem.Count() > 0 Then
		ReadInfoAboutNode(DataItem[0]);
		
		Object = DataItem.Filter.Object.Value;
		NumberOfUnsynchronizedVersions = NumberOfUnsynchronizedVersions(Object);
		VersionNumber = DataItem.Filter.VersionNumber.Value - DataItem[0].BeforeAfter + NumberOfUnsynchronizedVersions;
		DataItem[0].VersionOwner = DataItem[0].VersionOwner - DataItem[0].BeforeAfter + NumberOfUnsynchronizedVersions;
		
		RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
		RecordSet.Filter.Object.Set(Object);
		RecordSet.Filter.VersionNumber.Set(VersionNumber);
		RecordSet.Read();
		
		If Common.ValueToXMLString(DataItem) = Common.ValueToXMLString(RecordSet) Then
			// Consider that there are no conflicts.
			GetItem = DataItemReceive.Ignore;
			Return;
		EndIf;
		
		HasConflict = Object.GetObject() <> Undefined AND ExchangePlans.IsChangeRecorded(Sender.Ref, Object);
		
		ObjectVersionType = Enums.ObjectVersionTypes.NotAcceptedCollisionData;
		If Sender.AdditionalProperties.Property("RejectedDueToPeriodEndClosingDate")
			AND Sender.AdditionalProperties.RejectedDueToPeriodEndClosingDate[Object] <> Undefined Then
				HasConflict = True;
				If Sender.AdditionalProperties.RejectedDueToPeriodEndClosingDate[Object] = "RejectedDueToPeriodEndClosingDateObjectExistsInInfobase" Then
					ObjectVersionType = Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectExistsInInfobase;
				Else
					ObjectVersionType = Enums.ObjectVersionTypes.RejectedDueToPeriodEndClosingDateObjectDoesNotExistInInfobase;
				EndIf;
		EndIf;
		
		VersionsToExport = VersionsToExport(Object, Sender.Ref);
		For Each VersionToExport In VersionsToExport Do
			If VersionToExport.VersionNumber = VersionNumber Then
				HasConflict = True;
			EndIf;
		EndDo;
		
		If Not HasConflict Then
			// If the object was not changed, the version is overwritten without check because if the object was 
			// changed in the sender node is unknown.
			If RecordSet.Count() = 0 Then
				Record = RecordSet.Add();
				Record.Object = Object;
				Record.VersionNumber = VersionNumber;
			Else
				Record = RecordSet[0];
			EndIf;
			FillPropertyValues(Record, DataItem[0], , "Object,VersionNumber");
			RecordSet.Write();
			ExchangePlans.DeleteChangeRecords(Sender.Ref, RecordSet);
			GetItem = DataItemReceive.Ignore;
			Return;
		EndIf;
		
		LastVersionNumber = LastVersionNumber(Object);
		LatestVersion = InformationRegisters.ObjectsVersions.CreateRecordManager();
		LatestVersion.Object = Object;
		LatestVersion.VersionNumber = LastVersionNumber;
		LatestVersion.Read();
		If Not LatestVersion.HasVersionData Then
			LatestVersion.ObjectVersion = New ValueStorage(DataToStore(Object), New Deflation(9));
			LatestVersion.Write();
		EndIf;
		
		If VersionsToExport.Count() = 0 Then 
			Return;
		EndIf;
		
		For Each VersionDetails In VersionsToExport Do
			If VersionDetails.VersionNumber >= VersionNumber Then
				RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
				RecordSet.Filter.Object.Set(Object);
				RecordSet.Filter.VersionNumber.Set(VersionDetails.VersionNumber);
				RecordSet.Read();
				ExchangePlans.DeleteChangeRecords(Sender.Ref, RecordSet);
			EndIf;
		EndDo;
		
		ObjectVersionConflicts = New Map;
		If Sender.AdditionalProperties.Property("ObjectVersionConflicts") Then
			ObjectVersionConflicts = Sender.AdditionalProperties.ObjectVersionConflicts;
		Else
			Sender.AdditionalProperties.Insert("ObjectVersionConflicts", ObjectVersionConflicts);
		EndIf;
		
		ConflictVersionNumber = ObjectVersionConflicts[Object];
		VersionNumberShift = 1;
		SetRejectedVersionsOwner = False;
		If ConflictVersionNumber = Undefined Then
			VersionNumberShift = 2;
			ConflictVersionNumber = VersionNumber + 1;
			SetRejectedVersionsOwner = True;
		EndIf;
		
		RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
		RecordSet.Filter.Object.Set(Object);
		RecordSet.Read();
		ObjectVersions = RecordSet.Unload();
		For Each Version In ObjectVersions Do
			RecordSet.Filter.VersionNumber.Set(Version.VersionNumber);
			RecordSet.Read();
			Record = RecordSet[0];
			Write = False;
			If Record.VersionOwner >= VersionNumber Then
				Record.VersionOwner = Record.VersionOwner + VersionNumberShift;
				Write = True;
			EndIf;
			If Record.VersionNumber >= VersionNumber Then
				Record.VersionNumber = Record.VersionNumber + VersionNumberShift;
				Record.ObjectVersionType = ObjectVersionType;
				If SetRejectedVersionsOwner AND Not ValueIsFilled(Record.VersionOwner) Then
					Record.VersionOwner = ConflictVersionNumber;
				EndIf;
				Write = True;
			EndIf;
			If Write Then
				Records = RecordSet.Unload();
				RecordSet.Clear();
				RecordSet.Write();
				RecordSet.Filter.VersionNumber.Set(Records[0].VersionNumber);
				RecordSet.Load(Records);
				RecordSet.Write();
			EndIf;
		EndDo;
		
		If ObjectVersionConflicts[Object] = Undefined Then
			ConflictVersionNumber = VersionNumber + 1;
			
			RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
			RecordSet.Filter.Object.Set(Object);
			RecordSet.Filter.VersionNumber.Set(ConflictVersionNumber);
			Record = RecordSet.Add();
			
			LastVersionToExport = InformationRegisters.ObjectsVersions.CreateRecordManager();
			LastVersionToExport.Object = Object;
			LastVersionToExport.VersionNumber = VersionsToExport[0].VersionNumber + VersionNumberShift;
			LastVersionToExport.Read();
			
			FillPropertyValues(Record, LastVersionToExport, , "VersionOwner");
			Record.VersionNumber = ConflictVersionNumber;
			Record.VersionDate = CurrentSessionDate();
			Record.Comment = NStr("ru = 'Отклоненная версия (автоматическое разрешение конфликта).'; en = 'The rejected version (automatic conflict resolving).'; pl = 'Odrzucona wersja (automatyczne rozwiązywanie konfliktów).';es_ES = 'Versión denegada (resolución automática del conflicto).';es_CO = 'Versión denegada (resolución automática del conflicto).';tr = 'Reddedilen sürüm (otomatik çakışma çözümü).';it = 'La versione rifiutata (risoluzione automatica di conflitto).';de = 'Abgelehnte Version (automatische Konfliktlösung).'");
			Record.VersionAuthor = Common.ObjectManagerByRef(Sender.Ref).ThisNode();
			
			If Not Record.HasVersionData Then
				Record.ObjectVersion = New ValueStorage(DataToStore(Record.Object), New Deflation(9))
			EndIf;
			RecordSet.Write();
			
			ObjectVersionConflicts.Insert(Object, ConflictVersionNumber);
		EndIf;
	EndIf;
	
EndProcedure

// See StandardSubsystemsServer.OnSendDataToSlave. 
Procedure OnSendDataToSlave(DataItem, ItemSend, InitialImageCreation, Recipient) Export
	
	OnSendDataToRecipient(DataItem, ItemSend, Recipient);
	
EndProcedure

// See StandardSubsystemsServer.OnSendDataToMaster. 
Procedure OnSendDataToMaster(DataItem, ItemSend, Recipient) Export
	
	OnSendDataToRecipient(DataItem, ItemSend, Recipient);
	
EndProcedure

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure OnAddSessionParameterSettingHandlers(Handlers) Export
	
	Handlers.Insert("ObjectWritingInProgress",
		"ObjectsVersioning.SessionParametersSetting");
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.3.8";
	Handler.Procedure = "ObjectsVersioning.UpdateObjectsVersionsInformation";
	Handler.ExecutionMode = "Deferred";
	Handler.ID = New UUID("b403067e-7c2d-461c-89f9-5d5fc95dcab6");
	Handler.Comment = NStr("ru = 'Обновление сведений о записанных версиях объектов. После выполнения обновления увеличится скорость записи версионируемых объектов.'; en = 'Update information about written object versions. After updating, writing of versioned objects will be faster.'; pl = 'Aktualizacja informacji o zapisanych wersjach obiektów. Po wykonaniu aktualizacji zwiększy się prędkość zapisu wersjonowanych obiektów..';es_ES = 'El procedimiento de la información de las versiones guardadas de los objetos. Al actualizar se aumentará la velocidad de guardar los objetos versionados.';es_CO = 'El procedimiento de la información de las versiones guardadas de los objetos. Al actualizar se aumentará la velocidad de guardar los objetos versionados.';tr = 'Nesnelerin kaydedilmiş sürümleri hakkındaki bilgileri güncelleştirin. Yükseltmeyi gerçekleştirdikten sonra, yükseltilmiş nesnelerin yazma hızı artar.';it = 'Aggiornare informazioni sulle versione scritte degli oggetti. Dopo l''aggiornamento la scrittura di oggetti con versioni sarà più veloce.';de = 'Aktualisierung von Informationen über aufgezeichnete Versionen von Objekten. Nach dem Update erhöht sich die Geschwindigkeit der Aufzeichnung der versionierten Objekte.'");
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.4.13";
	Handler.Procedure = "ObjectsVersioning.MoveVersioningSettings";
	Handler.Comment = NStr("ru = 'Обновление настроек версионирования.'; en = 'Versioning setting update.'; pl = 'Aktualizacja ustawień wersjonowania.';es_ES = 'Actualización de los ajustes de versionado.';es_CO = 'Actualización de los ajustes de versionado.';tr = 'Sürüm ayarlarını güncelleme.';it = 'Aggiornamento impostazioni di versioning.';de = 'Aktualisieren der Versionierungseinstellungen.'");
	
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings. 
Procedure OnDefineScheduledJobSettings(Settings) Export
	Setting = Settings.Add();
	Setting.ScheduledJob = Metadata.ScheduledJobs.ClearingObsoleteObjectVersions;
	Setting.FunctionalOption = Metadata.FunctionalOptions.UseObjectsVersioning;
EndProcedure

// Handler of transition to the object version
//
// Parameters:
//	ObjectRef - Reference - Reference to the object which has a version.
//	NewVersionNumber - Number - Version number to migrate.
//	IgnoredVersionNumber - Number - Version number to ignore. 
//	SkipPeriodClosingCheck - Boolean - Flag specifying whether period-end closing  date check is skipped.
//
Procedure OnStartUsingNewObjectVersion(ObjectRef, Val VersionNumber) Export
	
	CheckObjectEditRights(ObjectRef.Metadata());
	
	SetPrivilegedMode(True);
	
	RecordSet = ObjectVersionRecord(ObjectRef, VersionNumber);
	Record = RecordSet[0];
	
	If Record.ObjectVersionType = Enums.ObjectVersionTypes.ConflictDataAccepted Then
		
		VersionNumber = VersionNumber - 1;
		
		If VersionNumber <> 0 Then
			
			PreviousRecord = ObjectVersionRecord(ObjectRef, VersionNumber)[0];
			VersionNumber = PreviousRecord.VersionNumber;
			
		EndIf;
		
	Else
		VersionNumber = Record.VersionNumber;
	EndIf;
	
	ErrorMessageText = "";
	GoToVersionServer(ObjectRef, VersionNumber, ErrorMessageText);
	
	If Not IsBlankString(ErrorMessageText) Then
		Raise ErrorMessageText;
	EndIf;
	
	Record.VersionIgnored = True;
	RecordSet.Write();
	
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not AccessRight("Edit", Metadata.InformationRegisters.ObjectVersioningSettings)
		Or ModuleToDoListServer.UserTaskDisabled("ObsoleteObjectVersions") Then
		Return;
	EndIf;
	
	// This procedure is only called when To-do list subsystem is available. Therefore, the subsystem 
	// availability check is redundant.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.InformationRegisters.ObjectVersioningSettings.FullName());
	
	ObsoleteVersionsInformation = ObsoleteVersionsInformation();
	ObsoleteDataSize = DataSizeString(ObsoleteVersionsInformation.DataSize);
	Tooltip = NStr("ru = 'Устаревших версий: %1 (%2)'; en = 'Obsolete versions: %1 (%2)'; pl = 'Przestarzałe wersje: %1 (%2)';es_ES = 'Versiones obsoletas: %1 (%2)';es_CO = 'Versiones obsoletas: %1 (%2)';tr = 'Eski sürümler: %1 (%2)';it = 'Versioni obsolete: %1 (%2)';de = 'Veraltete Versionen: %1 (%2)'");
	
	For Each Section In Sections Do
		ObsoleteObjectsID = "ObsoleteObjectVersions" + StrReplace(Section.FullName(), ".", "");
		// Adding a to-do.
		UserTask = ToDoList.Add();
		UserTask.ID = ObsoleteObjectsID;
		// Displaying a user task if the obsolete data exceeds 1 GB.
		UserTask.HasUserTasks      = ObsoleteVersionsInformation.DataSize > (1024 * 1024 * 1024);
		UserTask.Presentation = NStr("ru = 'Устаревшие версии объектов'; en = 'Obsolete object versions'; pl = 'Przestarzałe wersje obiektów';es_ES = 'Versiones del objeto obsoleto';es_CO = 'Versiones del objeto obsoleto';tr = 'Eski nesne sürümleri';it = 'Versioni obsolete dell''oggetto';de = 'Veraltete Objektversionen'");
		UserTask.Form         = "InformationRegister.ObjectVersioningSettings.Form.HistoryStorageSettings";
		UserTask.ToolTip     = StringFunctionsClientServer.SubstituteParametersToString(Tooltip, ObsoleteVersionsInformation.VersionsCount, ObsoleteDataSize);
		UserTask.Owner      = Section;
	EndDo;
	
EndProcedure

// See JobQueueOverridable.OnDefineHandlerAliases. 
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	NameAndAliasMap.Insert("ObjectsVersioning.ClearObsoleteObjectVersions");
	
EndProcedure

// See MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters. 
Procedure OnCollectConfigurationStatisticsParameters() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		Return;
	EndIf;
	
	ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
	
	QueryText =
	"SELECT
	|	VALUETYPE(ObjectsVersions.Object) AS ObjectType,
	|	SUM(1) AS Count
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|
	|GROUP BY
	|	VALUETYPE(ObjectsVersions.Object)";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	While Selection.Next() AND ValueIsFilled(Selection.ObjectType) Do
		MetadataObject = Metadata.FindByType(Selection.ObjectType);
		ModuleMonitoringCenter.WriteConfigurationObjectStatistics("ObjectVersionCount." + MetadataObject.FullName(), Selection.Count);
	EndDo;
	
	QueryText =
	"SELECT
	|	ObjectVersioningSettings.ObjectType.FullName AS ObjectName
	|FROM
	|	InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings
	|WHERE
	|	ObjectVersioningSettings.Use = TRUE";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ModuleMonitoringCenter.WriteConfigurationObjectStatistics("ObjectVersioningEnabled." + Selection.ObjectName, True);
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure SessionParametersSetting(ParameterName, SpecifiedParameters) Export
	
	If ParameterName = "ObjectWritingInProgress" Then
		ObjectWritingInProgress(False);
		SpecifiedParameters.Add("ObjectWritingInProgress");
	EndIf;
	
EndProcedure

// Creates an object version and writes it to the infobase.
//
Procedure CreateObjectVersion(Object, ObjectVersionInfo, NormalVersionRecord = True)
	
	CheckObjectEditRights(Object.Metadata());
	
	SetPrivilegedMode(True);
	
	If NormalVersionRecord Then
		PostingChanged = False;
		If ObjectVersionInfo.Property("PostingChanged") Then
			PostingChanged = ObjectVersionInfo.PostingChanged;
		EndIf;
		
		// Creates an object version and writes it to the infobase.
		If Not Object.IsNew() AND (PostingChanged AND ObjectVersionInfo.VersionNumber > 1 Or CurrentAndPreviousVersionMismatch(Object)) Then
			// If versioning is enabled after the object creation, the previous version is written to the infobase.
			If ObjectVersionInfo.VersionNumber = 1 Then
				If ObjectIsVersioned(Object.Ref, False) Then
					VersionParameters = New Structure;
					VersionParameters.Insert("VersionNumber", 1);
					VersionParameters.Insert("Comment", NStr("ru = 'Версия создана по уже имеющемуся объекту'; en = 'Version was created from the existing object'; pl = 'Wersja została utworzona z istniejącego obiektu';es_ES = 'Versión se ha creado desde el objeto existente';es_CO = 'Versión se ha creado desde el objeto existente';tr = 'Sürüm mevcut nesneden oluşturuldu';it = 'La versione è creata in base a un oggetto esistente';de = 'Die Version wurde aus dem vorhandenen Objekt erstellt'"));
					CreateObjectVersion(Object.Ref.GetObject(), VersionParameters);
					ObjectVersionInfo.VersionNumber = 2;
				EndIf;
			EndIf;
			
			// Saving the previous object version.
			RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
			RecordManager.Object = Object.Ref;
			RecordManager.VersionNumber = PreviousVersionNumber(Object.Ref, ObjectVersionInfo.VersionNumber);
			RecordManager.Read();
			If RecordManager.Selected() AND Not RecordManager.HasVersionData Then
				RecordManager.ObjectVersion = New ValueStorage(DataToStore(Object.Ref), New Deflation(9));
				RecordManager.Write();
			EndIf;
		EndIf;
		
		ObjectRef = Object.Ref;;
		If ObjectRef.IsEmpty() Then
			ObjectRef = Object.GetNewObjectRef();
			If ObjectRef.IsEmpty() Then
				ObjectRef = Common.ObjectManagerByRef(Object.Ref).GetRef();
				Object.SetNewObjectRef(ObjectRef);
			EndIf;
		EndIf;
		
		// Saving current version with no data.
		RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
		RecordManager.Object = ObjectRef;
		RecordManager.VersionNumber = ObjectVersionInfo.VersionNumber;
		RecordManager.VersionDate = CurrentSessionDate();
		
		VersionAuthor = Undefined;
		If Not Object.AdditionalProperties.Property("VersionAuthor", VersionAuthor) Then
			VersionAuthor = Users.AuthorizedUser();
		EndIf;
		RecordManager.VersionAuthor = VersionAuthor;
		
		RecordManager.ObjectVersionType = Enums.ObjectVersionTypes.ChangedByUser;
		RecordManager.Synchronized = True;
		ObjectVersionInfo.Property("Comment", RecordManager.Comment);
		
		If Not Object.IsNew() Then
			// Before calculating checksum, set posting status as it is expected to be after writing the 
			// document.
			If PostingChanged Then
				Object.Posted = Not Object.Posted;
			EndIf;
			
			RecordManager.Checksum = Checksum(DataToStore(Object));
			
			// Restore posting status to prevent failure of other functionality depending on this attribute.
			If PostingChanged Then
				Object.Posted = Not Object.Posted;
			EndIf;
		EndIf;
	Else
		// Saving the previous object version.
		RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
		RecordManager.Object = Object.Ref;
		RecordManager.VersionNumber = PreviousVersionNumber(Object.Ref, ObjectVersionInfo.VersionNumber);
		RecordManager.Read();
		If RecordManager.Selected() AND Not RecordManager.HasVersionData Then
			RecordManager.ObjectVersion = New ValueStorage(DataToStore(Object.Ref), New Deflation(9));
			RecordManager.Write();
		EndIf;
		
		BinaryData = SerializeObject(Object);
		DataStorage = New ValueStorage(BinaryData, New Deflation(9));
		RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
		RecordManager.VersionDate = CurrentSessionDate();
		RecordManager.ObjectVersion = DataStorage;
		FillPropertyValues(RecordManager, ObjectVersionInfo);
	EndIf;
	
	RecordManager.Write();
	
EndProcedure

// Writes an object version to the infobase.
//
// Parameters:
//	Object - to create version.
//
Procedure OnCreateObjectVersion(Object, WriteMode)
	
	Var LastVersionNumber, Comment;
	
	If NOT ObjectIsVersioned(Object, LastVersionNumber, WriteMode = DocumentWriteMode.Posting
		Or WriteMode = DocumentWriteMode.UndoPosting) Then
			Return;
	EndIf;
	
	If NOT Object.AdditionalProperties.Property("ObjectsVersioningVersionComment", Comment) Then
		Comment = "";
	EndIf;
	
	ObjectVersionInfo = New Structure;
	ObjectVersionInfo.Insert("VersionNumber", Number(LastVersionNumber) + 1);
	ObjectVersionInfo.Insert("Comment", Comment);
	
	PostingChanged = (WriteMode = DocumentWriteMode.Posting AND Not Object.Posted
		Or WriteMode = DocumentWriteMode.UndoPosting AND Object.Posted);
	ObjectVersionInfo.Insert("PostingChanged", PostingChanged);
	
	CreateObjectVersion(Object, ObjectVersionInfo);
	
EndProcedure

Procedure WriteCurrentVersionData(Ref, DataExchangeImport = False)
	Var LastVersionNumber;
	
	SetPrivilegedMode(True);
	
	If Not ObjectIsVersioned(Ref, LastVersionNumber) Then
		Return;
	EndIf;
	
	ObjectVersion = New ValueStorage(DataToStore(Ref), New Deflation(9));
	
	RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
	RecordSet.Filter.Object.Set(Ref);
	RecordSet.Filter.VersionNumber.Set(LastVersionNumber);
	RecordSet.Read();
	
	For Each Record In RecordSet Do
		Record.ObjectVersion = ObjectVersion;
	EndDo;
	
	If DataExchangeImport Then
		RecordSet.AdditionalProperties.Insert("RegisterAtExchangePlanNodesOnUpdateIB", False);
	EndIf;
	RecordSet.Write();
EndProcedure


Function ObjectVersionRecord(ObjectRef, VersionNumber)
	
	RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
	RecordSet.Filter.Object.Set(ObjectRef);
	RecordSet.Filter.VersionNumber.Set(VersionNumber);
	RecordSet.Read();
	
	Return RecordSet;
	
EndFunction

Procedure CheckObjectEditRights(MetadataObject)
	
	If Not PrivilegedMode() AND Not AccessRight("Update", MetadataObject)Then
		MessageText = NStr("ru = 'Недостаточно прав на изменение ""%1"".'; en = 'Insufficient rights to modify %1.'; pl = 'Niewystarczające uprawnienia do zmiany ""%1"".';es_ES = 'Insuficientes derechos para cambiar ""%1"".';es_CO = 'Insuficientes derechos para cambiar ""%1"".';tr = '""%1"" değiştirmek için haklar yetersiz.';it = 'Permessi insufficienti per modificare %1.';de = 'Unzureichende Rechte zum Ändern ""%1"".'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, MetadataObject.Presentation());
		Raise MessageText;
	EndIf;
	
EndProcedure

// Returns a spreadsheet document filled with the object data.
// 
// Parameters:
//  ObjectRef - AnyRef.
//
// Returns:
//  SpreadsheetDocument - object print form.
//
Function ReportOnObjectVersion(ObjectRef, Val ObjectVersion = Undefined, CustomVersionNumber = Undefined) Export
	
	VersionNumber = Undefined;
	SerializedObject = Undefined;
	If TypeOf(ObjectVersion) = Type("Number") Then
		VersionNumber = ObjectVersion;
	ElsIf TypeOf(ObjectVersion) = Type("String") Then
		SerializedObject = ObjectVersion;
	EndIf;
	
	If VersionNumber = Undefined Then
		If SerializedObject = Undefined Then
			SerializedObject = SerializeObject(ObjectRef.GetObject());
		EndIf;
		ObjectDetails = XMLObjectPresentationParsing(SerializedObject, ObjectRef);
		ObjectDetails.Insert("ObjectName",     String(ObjectRef));
		ObjectDetails.Insert("ChangeAuthor", "");
		ObjectDetails.Insert("ChangeDate",  CurrentSessionDate());
		ObjectDetails.Insert("Comment", "");
		VersionNumber = 0;
		
		ObjectsVersioningOverridable.AfterParsingObjectVersion(ObjectRef, ObjectDetails);
	Else
		ObjectDetails = ParseVersion(ObjectRef, VersionNumber);
	EndIf;
	
	If CustomVersionNumber = Undefined Then
		CustomVersionNumber = VersionNumberInHierarchy(ObjectRef, VersionNumber);
	EndIf;
	
	Details = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '№ %1 / (%2) / %3'; en = 'No. %1 / (%2) / %3'; pl = '№ %1 / (%2) / %3';es_ES = '№ %1 / (%2) / %3';es_CO = '№ %1 / (%2) / %3';tr = '№ %1 / (%2) / %3';it = 'No. %1 / (%2) / %3';de = '№ %1 / (%2) / %3'"), CustomVersionNumber,
		String(ObjectDetails.ChangeDate), TrimAll(String(ObjectDetails.ChangeAuthor)));
		
	ObjectDetails.Insert("Details", Details);
	ObjectDetails.Insert("VersionNumber", VersionNumber);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	GenerateObjectVersionReport(SpreadsheetDocument, ObjectDetails, ObjectRef);
	
	Return SpreadsheetDocument;
	
EndFunction

// Returns number of the last saved object version.
//
// Parameters:
//  Reference - AnyRef - reference to an infobase object.
//
// Returns:
//  Number - object version number.
//
Function LastVersionNumber(Ref, ChangedByUser = False) Export
	
	If Ref.IsEmpty() Then
		Return 0;
	EndIf;
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT
	|	ISNULL(MAX(ObjectsVersions.VersionNumber), 0) AS VersionNumber
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.Object = &Ref
	|	AND &AdditionalCondition";
	
	If ChangedByUser Then
		AdditionalCondition = "ObjectsVersions.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.ChangedByUser)";
	Else
		AdditionalCondition = "TRUE";
	EndIf;
	QueryText = StrReplace(QueryText, "&AdditionalCondition", AdditionalCondition);
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("ChangedByUser", ChangedByUser);
	
	If TransactionActive() Then
		DataLock = New DataLock();
		LockItem = DataLock.Add("InformationRegister.ObjectsVersions");
		LockItem.SetValue("Object", Ref);
		DataLock.Lock();
	EndIf;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.VersionNumber;
	
EndFunction

// Previous version number changed by user.
Function PreviousVersionNumber(Ref, VersionCurrentNumber)
	
	If Ref.IsEmpty() Then
		Return 0;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ISNULL(MAX(ObjectsVersions.VersionNumber), -1) AS VersionNumber
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.Object = &Ref
	|	AND ObjectsVersions.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.ChangedByUser)
	|	AND ObjectsVersions.VersionNumber < &VersionCurrentNumber";
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("VersionCurrentNumber", VersionCurrentNumber);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.VersionNumber;
	
EndFunction

// Returns full names of metadata objects with versioning mechanism enabled.
//
// Returns:
//  Array of strings - names of metadata objects.
//
Function GetVersionedObjects()
	
	Result = New Array;
	
	For Each Type In Metadata.CommonCommands.ChangeHistory.CommandParameterType.Types() Do
		Result.Add(Common.MetadataObjectID(Type));
	EndDo;
	
	Return Result;
	
EndFunction

// Returns a versioning mode enabled for the specified metadata object.
//
// Parameters:
//  ObjectType - CatalogRef.MetadataObjectID - MOID.
//
// Returns:
//  Enum.ObjectVersioningModes.
//
Function ObjectVersioningOption(ObjectType)
	
	Return GetFunctionalOption("ObjectsVersioningOptions",
		New Structure("VersionizedObjectType", ObjectType));
		
EndFunction	

// Gets an object by its serialized XML presentation.
//
// Parameters:
//  AddressInTempStorage - String - binary data address in temporary storage.
//  ErrorMessageText    - String - error text (return value) when the object cannot be restored.
//
// Returns - Object or Undefined.
//
Function RestoreObjectByXML(ObjectData, ErrorMessageText = "")
	
	SetPrivilegedMode(True);
	
	BinaryData = ObjectData;
	If TypeOf(ObjectData) = Type("Structure") Then
		BinaryData = ObjectData.Object;
	EndIf;
	
	FastInfosetReader = New FastInfosetReader;
	FastInfosetReader.SetBinaryData(BinaryData);
	
	Try
		Object = ReadXML(FastInfosetReader);
	Except
		WriteLogEvent(NStr("ru = 'Версионирование'; en = 'Versioning'; pl = 'Zarządzanie wersjami';es_ES = 'Versionando';es_CO = 'Versionando';tr = 'Sürüm belirleme';it = 'Versionamento';de = 'Versionierung'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		ErrorMessageText = NStr("ru = 'Не удалось перейти на выбранную версию.
											|Возможная причина: версия объекта была записана в другой версии программы.
											|Техническая информация об ошибке: %1'; 
											|en = 'Cannot transfer to the selected version.
											|Possible causes: the object version was written in another application version.
											|Technical information about the error: %1'; 
											|pl = 'Nie udało się przejść do wybranej wersji.
											|Możliwa przyczyna: wersja obiektu została zarejestrowana w innej wersji aplikacji.
											|Informacje techniczne dotyczące błędu: %1';
											|es_ES = 'Fallado a proceder a la versión seleccionada.
											|Posible causa: la versión del objeto se ha grabado en la versión de otra aplicación.
											|Información técnica sobre el error: %1';
											|es_CO = 'Fallado a proceder a la versión seleccionada.
											|Posible causa: la versión del objeto se ha grabado en la versión de otra aplicación.
											|Información técnica sobre el error: %1';
											|tr = 'Seçilen sürüme geçemedi. 
											|Olası neden: Nesne sürümü başka bir uygulama sürümünde kaydedildi. 
											|Hata hakkında teknik bilgi:%1';
											|it = 'Impossibile trasferire alla versione selezionata.
											|Possibili cause: La versione dell''oggetto è stata registrata in una versione diversa del programma.
											|Informazione tecnica sull''errore: %1';
											|de = 'Fehler beim Fortsetzen mit der ausgewählten Version.
											|Mögliche Ursache: Die Objektversion wurde in einer anderen Anwendungsversion aufgezeichnet.
											|Technische Informationen zum Fehler: %1'");
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageText, BriefErrorDescription(ErrorInfo()));
		Return Undefined;
	EndTry;
	
	Return Object;
	
EndFunction

// Returns a structure containing object version and additional information.
//
// Parameters:
//  Reference      - Reference - reference to the versioned object;
//  VersionNumber - Number  - object version number.
//
// Returns - Structure:
//                          ObjectVersion - BinaryData - saved version of the infobase object;
//                          VersionAuthor - Catalog.Users, Catalog.ExternalUsers - the user who 
//                                          wrote the object version.
//                          VersionDate    - Date - object version write date.
// 
// Note:
//  This function can raise an exception if a record contains no data.
//  The function must be called in privileged mode.
//
Function ObjectVersionInfo(Val Ref, Val VersionNumber) Export
	MessageCannotGetVersion = NStr("ru = 'Не удалось получить предыдущую версию объекта.'; en = 'Cannot get previous version of the object.'; pl = 'Nie można odebrać poprzedniej wersji obiektu.';es_ES = 'No se puede recibir una versión previa del objeto.';es_CO = 'No se puede recibir una versión previa del objeto.';tr = 'Nesnenin önceki sürümü alınamıyor.';it = 'Impossibile prendere la versione precedente dell''oggetto.';de = 'Kann eine vorherige Version des Objekts nicht empfangen.'");
	If Not HasRightToReadObjectVersionData() Then
		Raise MessageCannotGetVersion;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ObjectsVersions.VersionAuthor AS VersionAuthor,
	|	ObjectsVersions.VersionDate AS VersionDate,
	|	ObjectsVersions.Comment AS Comment,
	|	ObjectsVersions.ObjectVersion,
	|	ObjectsVersions.Checksum
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.Object = &Ref
	|	AND ObjectsVersions.VersionNumber = &VersionNumber";
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("VersionNumber", Number(VersionNumber));
	
	Result = New Structure("ObjectVersion, VersionAuthor, VersionDate, Comment");
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(Result, Selection);
		Result.ObjectVersion = Result.ObjectVersion.Get();
		If Result.ObjectVersion = Undefined Then
			Result.ObjectVersion = ObjectVersionData(Ref, VersionNumber, Selection.Checksum);
		EndIf;
		
	EndIf;
	
	If Result.ObjectVersion = Undefined Then
		Raise NStr("ru = 'Выбранная версия объекта отсутствует в программе.'; en = 'Selected object version is not available in the application.'; pl = 'W aplikacji brakuje wybranej wersji obiektu.';es_ES = 'La versión del objeto seleccionado está faltando en la aplicación.';es_CO = 'La versión del objeto seleccionado está faltando en la aplicación.';tr = 'Seçilen nesne sürümü uygulamada eksik.';it = 'La versione selezionata dell''oggetto non è disponibile nell''applicazione.';de = 'Die ausgewählte Objektversion fehlt in der Anwendung.'");
	EndIf;
	
	Return Result;
		
EndFunction

// Checks versioning settings for the passed object and returns the versioning mode.
//  If versioning is not enabled for the object, the default versioning rules apply.
// 
// 
//
Function ObjectIsVersioned(Val Source, LastVersionNumber, WriteModePosting = False)
	
	LastVersionNumber = LastVersionNumber(Source.Ref);
	
	// Making sure that versioning subsystem is active.
	If NOT GetFunctionalOption("UseObjectsVersioning") Then
		Return False;
	EndIf;
	
	VersioningMode = ObjectVersioningOption(Common.MetadataObjectID(Source.Metadata()));
	If VersioningMode = False Then
		VersioningMode = Enums.ObjectsVersioningOptions.DontVersionize;
	EndIf;
	
	Return LastVersionNumber > 0 
		Or VersioningMode = Enums.ObjectsVersioningOptions.VersionizeOnWrite
		Or VersioningMode = Enums.ObjectsVersioningOptions.VersionizeOnPost AND (WriteModePosting Or Source.Posted)
		Or VersioningMode = Enums.ObjectsVersioningOptions.VersionizeOnStart AND Source.Started;
	
EndFunction

// MD5 checksum.
Function Checksum(Data) Export
	DataHashing = New DataHashing(HashFunction.MD5);
	
	If TypeOf(Data) = Type("Structure") Then
		DataHashing.Append(Data.Object);
		If Data.Property("AdditionalAttributes") Then
			DataHashing.Append(Common.ValueToXMLString(Data.AdditionalAttributes));
		EndIf;
	Else
		DataHashing.Append(Data);
	EndIf;
	
	Return StrReplace(DataHashing.HashSum, " ", "");
EndFunction

Function ObjectVersionData(ObjectRef, VersionNumber, Checksum)
	
	If Not IsBlankString(Checksum) Then
		QueryText = 
		"SELECT TOP 1
		|	ObjectsVersions.ObjectVersion,
		|	ObjectsVersions.VersionNumber
		|FROM
		|	InformationRegister.ObjectsVersions AS ObjectsVersions
		|WHERE
		|	ObjectsVersions.Object = &Object
		|	AND ObjectsVersions.VersionNumber >= &VersionNumber
		|	AND ObjectsVersions.Checksum = &Checksum
		|
		|ORDER BY
		|	ObjectsVersions.VersionNumber DESC";
		
		Query = New Query(QueryText);
		Query.SetParameter("Object", ObjectRef);
		Query.SetParameter("VersionNumber", VersionNumber);
		Query.SetParameter("Checksum", Checksum);
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Result = Selection.ObjectVersion.Get();
			If Result = Undefined AND Selection.VersionNumber = LastVersionNumber(ObjectRef, True) Then
				Result = DataToStore(ObjectRef);
			EndIf;
			Return Result;
		EndIf;
	Else
		QueryText = 
		"SELECT TOP 1
		|	ObjectsVersions.Checksum
		|FROM
		|	InformationRegister.ObjectsVersions AS ObjectsVersions
		|WHERE
		|	ObjectsVersions.Object = &Object
		|	AND ObjectsVersions.VersionNumber >= &VersionNumber
		|	AND ObjectsVersions.Checksum <> """"
		|
		|ORDER BY
		|	ObjectsVersions.VersionNumber";
		
		Query = New Query(QueryText);
		Query.SetParameter("Object", ObjectRef);
		Query.SetParameter("VersionNumber", VersionNumber);
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Return ObjectVersionData(ObjectRef, VersionNumber, Selection.Checksum);
		EndIf;
		
		Return DataToStore(ObjectRef);
	EndIf;
	
EndFunction

Function CurrentAndPreviousVersionMismatch(Object)
	
	QueryText = 
	"SELECT TOP 1
	|	ObjectsVersions.Checksum
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.Object = &Object
	|
	|ORDER BY
	|	ObjectsVersions.VersionNumber DESC";
	
	Query = New Query(QueryText);
	Query.SetParameter("Object", Object.Ref);
	Selection = Query.Execute().Select();
	If Selection.Next() AND Not IsBlankString(Selection.Checksum) Then
		Return Selection.Checksum <> Checksum(DataToStore(Object));
	EndIf;
	
	Return Object.IsNew() Or Checksum(DataToStore(Object)) <> Checksum(DataToStore(Object.Ref.GetObject()));
	
EndFunction

// For internal use only.
Procedure ClearObsoleteObjectVersions(Parameters = Undefined, ResultAddress = Undefined) Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.ClearingObsoleteObjectVersions);
	
	SetPrivilegedMode(True);
	
	ObjectDeletionBoundaries = ObjectDeletionBoundaries();
	
	Query = New Query;
	QueryText =
	"SELECT
	|	ObjectsVersions.Object,
	|	ObjectsVersions.VersionNumber
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.HasVersionData
	|	AND &AdditionalConditions";
	
	AdditionalConditions = "";
	For Index = 0 To ObjectDeletionBoundaries.Count() - 1 Do
		If Not IsBlankString(AdditionalConditions) Then
			AdditionalConditions = AdditionalConditions + "
			|	OR";
		EndIf;
		IndexString = Format(Index, "NZ=0; NG=0");
		Condition = "";
		For Each Type In ObjectDeletionBoundaries[Index].TypesList Do
			If Not IsBlankString(Condition) Then
				Condition = Condition + "
				|	OR";
			EndIf;
			Condition = Condition + "
			|	ObjectsVersions.Object REFS " + Type;
		EndDo;
		If IsBlankString(Condition) Then
			Continue;
		EndIf;
		Condition = "(" + Condition + ")";
		AdditionalConditions = AdditionalConditions + StringFunctionsClientServer.SubstituteParametersToString(
			"
			|	%1
			|	AND ObjectsVersions.VersionDate < &DeletionBoundary%2",
			Condition,
			IndexString);
		Query.SetParameter("TypesList" + IndexString, ObjectDeletionBoundaries[Index].TypesList);
		Query.SetParameter("DeletionBoundary" + IndexString, ObjectDeletionBoundaries[Index].DeletionBoundary);
	EndDo;

	If IsBlankString(AdditionalConditions) Then
		AdditionalConditions = "FALSE";
	Else
		AdditionalConditions = "(" + AdditionalConditions + ")";
	EndIf;
	
	QueryText = StrReplace(QueryText, "&AdditionalConditions", AdditionalConditions);
	
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
		RecordManager.Object = Selection.Object;
		RecordManager.VersionNumber = Selection.VersionNumber;
		RecordManager.Read();
		RecordManager.ObjectVersion = Undefined;
		RecordManager.Write();
	EndDo;
	
EndProcedure

Function ObjectDeletionBoundaries()
	
	Result = New ValueTable;
	Result.Columns.Add("TypesList", New TypeDescription("Array"));
	Result.Columns.Add("DeletionBoundary", New TypeDescription("Date"));
	
	QueryText =
	"SELECT
	|	ObjectVersioningSettings.ObjectType.FullName AS ObjectType,
	|	ObjectVersioningSettings.VersionsLifetime AS VersionsLifetime
	|FROM
	|	InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings
	|WHERE
	|	NOT ObjectVersioningSettings.ObjectType.DeletionMark
	|
	|ORDER BY
	|	VersionsLifetime
	|TOTALS BY
	|	VersionsLifetime";
	
	Query = New Query(QueryText);
	LifetimeSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	While LifetimeSelection.Next() Do
		ObjectSelection = LifetimeSelection.Select();
		TypesList = New Array;
		While ObjectSelection.Next() Do
			TypesList.Add(ObjectSelection.ObjectType);
		EndDo;
		BoundaryAndObjectTypesMap = Result.Add();
		BoundaryAndObjectTypesMap.DeletionBoundary = DeletionBoundary(LifetimeSelection.VersionsLifetime);
		BoundaryAndObjectTypesMap.TypesList = TypesList;
	EndDo;
	
	Return Result;
	
EndFunction

Function DeletionBoundary(VersionLifetime)
	If VersionLifetime = Enums.VersionsLifetimes.LastYear Then
		Return AddMonth(CurrentSessionDate(), -12);
	ElsIf VersionLifetime = Enums.VersionsLifetimes.LastSixMonths Then
		Return AddMonth(CurrentSessionDate(), -6);
	ElsIf VersionLifetime = Enums.VersionsLifetimes.LastThreeMonths Then
		Return AddMonth(CurrentSessionDate(), -3);
	ElsIf VersionLifetime = Enums.VersionsLifetimes.LastMonth Then
		Return AddMonth(CurrentSessionDate(), -1);
	ElsIf VersionLifetime = Enums.VersionsLifetimes.LastWeek Then
		Return CurrentSessionDate() - 7*24*60*60;
	Else // VersionLifetime = Enums.VersionLifetimes.Infinite
		Return '000101010000';
	EndIf;
EndFunction

Procedure OnSendDataToRecipient(DataItem, ItemSend, Recipient)
	
	If TypeOf(DataItem) = Type("InformationRegisterRecordSet.ObjectsVersions") AND DataItem.Count() > 0 Then
		Record = DataItem[0];
		
		If Not Record.Synchronized Then
			ItemSend = DataItemSend.Ignore;
			Return;
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
			Cancel = False;
			Object = Record.Object.GetObject();
			ModuleDataExchangeEvents = Common.CommonModule("DataExchangeEvents");
			ModuleDataExchangeEvents.ObjectsRegistrationMechanismBeforeWrite(Recipient.Metadata().Name, Object, Cancel);
			If Cancel Or Not Object.DataExchange.Recipients.Contains(Recipient.Ref) Then
				ItemSend = DataItemSend.Ignore;
				Return;
			EndIf;
		EndIf;
		
		AddInfoAboutNode(Record, Recipient);
		
		If LastVersionNumber(Record.Object, True) = Record.VersionNumber Then
			Record.ObjectVersion = New ValueStorage(DataToStore(Record.Object), New Deflation(9));
			Record.DataSize = DataSize(Record.ObjectVersion);
			Record.HasVersionData = True;
		EndIf;
		
		Record.BeforeAfter = NumberOfUnsynchronizedVersions(Record.Object);
	EndIf;
	
EndProcedure

// For internal use only.
// The comment is only saved when the user is either version author or administrator.
Procedure AddCommentToVersion(ObjectRef, VersionNumber, Comment) Export
	
	If Not HasRightToReadObjectVersionData() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.ObjectsVersions.CreateRecordManager();
	RecordManager.Object = ObjectRef;
	RecordManager.VersionNumber = VersionNumber;
	RecordManager.Read();
	If RecordManager.Selected() Then
		If RecordManager.VersionAuthor = Users.CurrentUser() Or Users.IsFullUser(, , False) Then
			RecordManager.Comment = Comment;
			RecordManager.Write();
		EndIf;
	EndIf;
	
EndProcedure

// Provides information on the number and size of obsolete object versions.
Function ObsoleteVersionsInformation()
	
	SetPrivilegedMode(True);
	
	ObjectDeletionBoundaries = ObjectDeletionBoundaries();
	
	Query = New Query;
	QueryText =
	"SELECT
	|	ISNULL(SUM(ObjectsVersions.DataSize), 0) AS DataSize,
	|	ISNULL(SUM(1), 0) AS VersionsCount
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.HasVersionData
	|	AND &AdditionalConditions";
	
	AdditionalConditions = "";
	For Index = 0 To ObjectDeletionBoundaries.Count() - 1 Do
		If Not IsBlankString(AdditionalConditions) Then
			AdditionalConditions = AdditionalConditions + "
			|	OR";
		EndIf;
		IndexString = Format(Index, "NZ=0; NG=0");
		Condition = "";
		For Each Type In ObjectDeletionBoundaries[Index].TypesList Do
			If Not IsBlankString(Condition) Then
				Condition = Condition + "
				|	OR";
			EndIf;
			Condition = Condition + "
			|	ObjectsVersions.Object REFS " + Type;
		EndDo;
		If IsBlankString(Condition) Then
			Continue;
		EndIf;
		Condition = "(" + Condition + ")";
		AdditionalConditions = AdditionalConditions + StringFunctionsClientServer.SubstituteParametersToString(
			"
			|	%1
			|	AND ObjectsVersions.VersionDate < &DeletionBoundary%2",
			Condition,
			IndexString);
		Query.SetParameter("TypesList" + IndexString, ObjectDeletionBoundaries[Index].TypesList);
		Query.SetParameter("DeletionBoundary" + IndexString, ObjectDeletionBoundaries[Index].DeletionBoundary);
	EndDo;

	If IsBlankString(AdditionalConditions) Then
		AdditionalConditions = "FALSE";
	Else
		AdditionalConditions = "(" + AdditionalConditions + ")";
	EndIf;
	
	QueryText = StrReplace(QueryText, "&AdditionalConditions", AdditionalConditions);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	VersionsCount = 0;
	DataSize = 0;
	If Selection.Next() Then
		DataSize = Selection.DataSize;
		VersionsCount = Selection.VersionsCount;
	EndIf;
	
	Result = New Structure;
	Result.Insert("VersionsCount", VersionsCount);
	Result.Insert("DataSize", DataSize);
	
	Return Result;
	
EndFunction

// See ObsoleteVersionsInfo. 
Procedure InfoOnOutdatedVersionsOnBackground(AdditionalParameters, AddressInTempStorage) Export
	Result = ObsoleteVersionsInformation();
	Result.Insert("DataSizeString", DataSizeString(Result.DataSize));
	PutToTempStorage(Result, AddressInTempStorage);
EndProcedure

// String presentation of data volumes. For example: "1.23 GB".
Function DataSizeString(Val DataSize)
	
	UnitOfMeasure = NStr("ru = 'байт'; en = 'byte'; pl = 'bajt';es_ES = 'byte';es_CO = 'byte';tr = 'bayt';it = 'byte';de = 'Byte'");
	If 1024 <= DataSize AND DataSize < 1024 * 1024 Then
		DataSize = DataSize / 1024;
		UnitOfMeasure = NStr("ru = 'Кб'; en = 'KB'; pl = 'KB';es_ES = 'kB';es_CO = 'kB';tr = 'Kb';it = 'KB';de = 'KB'");
	ElsIf 1024 * 1024 <= DataSize AND  DataSize < 1024 * 1024 * 1024 Then
		DataSize = DataSize / 1024 / 1024;
		UnitOfMeasure = NStr("ru = 'Мб'; en = 'MB'; pl = 'MB';es_ES = 'MB';es_CO = 'MB';tr = 'MB';it = 'MB';de = 'MB'");
	ElsIf 1024 * 1024 * 1024 <= DataSize Then
		DataSize = DataSize / 1024 / 1024 / 1024;
		UnitOfMeasure = NStr("ru = 'Гб'; en = 'GB'; pl = 'GB';es_ES = 'GB';es_CO = 'GB';tr = 'GB';it = 'GB';de = 'GB'");
	EndIf;
	
	If DataSize < 10 Then
		DataSize = Round(DataSize, 2);
	ElsIf DataSize < 100 Then
		DataSize = Round(DataSize, 1);
	Else
		DataSize = Round(DataSize, 0);
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 %2'; en = '%1 %2'; pl = '%1 %2';es_ES = '%1 %2';es_CO = '%1 %2';tr = '%1 %2';it = '%1 %2';de = '%1 %2'"), DataSize, UnitOfMeasure);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions related to object report generation.

// Returns a serialized object in the binary data format.
//
// Parameters:
//  Object - Any - serialized object.
//
// Returns:
//  BinaryData - serialized object.
Function SerializeObject(Object) Export
	
	XMLWriter = New FastInfosetWriter;
	XMLWriter.SetBinaryData();
	XMLWriter.WriteXMLDeclaration();
	
	WriteXML(XMLWriter, Object, XMLTypeAssignment.Explicit);
	
	Return XMLWriter.Close();

EndFunction

// Reads XML data from file and fills data structures.
//
// Returns:
// Structure containing two maps: TabularSections and Attributes.
// Data storage structure:
// Map TabularSections containing the tabular section values in format: 
// 
//          СоответствиеИмя1 -> ТаблицаЗначений1
//                            |      |     ... |
//                            Field1  Field2     FieldM1.
//
//          MapName2 -> ValueTable2
//                            |      |     ... |
//                            Field1  Field2     FieldM2.
//
//
//          MapNameN -> MapNameN
//                            |      |     ... |
//                            Field1  Field2     FieldM3.
//
// Map AttributeValues
//          AttributeName1 -> Value1
//          AttributeName2 -> Value2
//          ...
//          AttributeNameN -> ValueN.
//
Function XMLObjectPresentationParsing(VersionData, Ref) Export
	
	Result = New Structure;
	Result.Insert("SpreadsheetDocuments");
	Result.Insert("AdditionalAttributes");
	Result.Insert("HiddenAttributes", New Array);
	
	BinaryData = VersionData;
	If TypeOf(VersionData) = Type("Structure") Then
		BinaryData = VersionData.Object;
		VersionData.Property("SpreadsheetDocuments", Result.SpreadsheetDocuments);
		VersionData.Property("AdditionalAttributes", Result.AdditionalAttributes);
		VersionData.Property("HiddenAttributes", Result.HiddenAttributes);
	EndIf;
	
	AttributeValues = New ValueTable;
	AttributeValues.Columns.Add("AttributeDescription");
	AttributeValues.Columns.Add("AttributeValue");
	AttributeValues.Columns.Add("AttributeType");
	AttributeValues.Columns.Add("Type");
	
	TabularSections = New Map;
	
	XMLReader = New FastInfosetReader;
	XMLReader.SetBinaryData(BinaryData);
	
	// Marker position level in XML hierarchy:
	// 0 - level not defined
	// 1 - first element (object name)
	// 2 - attribute or tabular section description
	// 3 - tabular section string description
	// 4 - tabular section string field description.
	ReadingLevel = 0;
	
	ObjectMetadata = Ref.Metadata();
	TSFieldValueType = "";
	
	// Main XML parsing cycle.
	While XMLReader.Read() Do
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			ReadingLevel = ReadingLevel + 1;
			If ReadingLevel = 1 Then // Pointer set to the first XML element - XML root.
				// Object name in XMLReader.Name, but it is not required.
			ElsIf ReadingLevel = 2 Then // Level-two pointer is an attribute or a tabular section name.
				AttributeName = XMLReader.Name;
				
				// Saving the attribute against a possible case that it may be a tabular section.
				TabularSectionName = AttributeName;
				If TabularSectionMetadata(ObjectMetadata, TabularSectionName) <> Undefined Then
					TabularSections.Insert(TabularSectionName, New ValueTable);
				EndIf;
				
				NewAV = AttributeValues.Add();
				NewAV.AttributeDescription = AttributeName;
				
				If XMLReader.AttributeCount() > 0 Then
					While XMLReader.ReadAttribute() Do
						If XMLReader.NodeType = XMLNodeType.Attribute 
							AND XMLReader.Name = "xsi:type" Then
								NewAV.AttributeType = XMLReader.Value;
								XMLType = XMLReader.Value;
								If StrStartsWith(XMLType, "xs:") Then
									NewAV.Type = FromXMLType(New XMLDataType(Right(XMLType, StrLen(XMLType)-3), "http://www.w3.org/2001/XMLSchema"));
								Else
									NewAV.Type = FromXMLType(New XMLDataType(XMLType, ""));
								EndIf;
						EndIf;
					EndDo;
				EndIf;
				
				If Not ValueIsFilled(NewAV.Type) Then
					AttributeDetails = AttributeMetadata(ObjectMetadata, AttributeName);
					If AttributeDetails = Undefined Then
						AttributeDetails = Metadata.CommonAttributes.Find(AttributeName);
					EndIf;
					If AttributeDetails = Undefined AND Metadata.ChartsOfAccounts.Contains(ObjectMetadata) Then
						AttributeDetails = ObjectMetadata.AccountingFlags.Find(AttributeName);
					EndIf;
					
					If AttributeDetails <> Undefined
						AND AttributeDetails.Type.Types().Count() = 1 Then
						NewAV.Type = AttributeDetails.Type.Types()[0];
					EndIf;
				EndIf;
			ElsIf (ReadingLevel = 3) AND XMLReader.Name = "Row" Then // Pointer to tabular section field.
				If TabularSections[TabularSectionName] = Undefined Then
					TabularSections.Insert(TabularSectionName, New ValueTable);
				EndIf;
				TabularSections[TabularSectionName].Add();
			ElsIf ReadingLevel = 4 Then
				If XMLReader.Name = "v8:Type" Then
					If NewAV.AttributeValue = Undefined Then
						NewAV.AttributeValue = "";
					EndIf;
				Else // Pointer to tabular section field.
					TSFieldValueType = "";
					TSFieldName = XMLReader.Name;
					Table   = TabularSections[TabularSectionName];
					If Table.Columns.Find(TSFieldName)= Undefined Then
						Table.Columns.Add(TSFieldName);
					EndIf;
					
					If XMLReader.AttributeCount() > 0 Then
						While XMLReader.ReadAttribute() Do
							If XMLReader.NodeType = XMLNodeType.Attribute 
								AND XMLReader.Name = "xsi:type" Then
									XMLType = XMLReader.Value;
									If StrStartsWith(XMLType, "xs:") Then
										TSFieldValueType = FromXMLType(New XMLDataType(Right(XMLType, StrLen(XMLType)-3), "http://www.w3.org/2001/XMLSchema"));
									Else
										TSFieldValueType = FromXMLType(New XMLDataType(XMLType, ""));
									EndIf;
							EndIf;
						EndDo;
					EndIf;
				EndIf;
			EndIf;
		ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
			ReadingLevel = ReadingLevel - 1;
		ElsIf XMLReader.NodeType = XMLNodeType.Text Then
			If (ReadingLevel = 2) Then // attribute value
				Try
					NewAV.AttributeValue = ?(ValueIsFilled(NewAV.Type), XMLValue(NewAV.Type, XMLReader.Value), XMLReader.Value);
				Except
					NewAV.AttributeValue = XMLReader.Value;
				EndTry;
			ElsIf (ReadingLevel = 4) Then // attribute value
				If NewAV.Type = Type("TypeDescription") Then
					TypeString = String(FromXMLType(New XMLDataType(XMLReader.Value, "")));
					If IsBlankString(TypeString) Then
						TypeString = XMLReader.Value;
					EndIf;
					If Not IsBlankString(NewAV.AttributeValue) Then
						NewAV.AttributeValue = NewAV.AttributeValue + Chars.LF;
					EndIf;
					NewAV.AttributeValue = NewAV.AttributeValue + TypeString;
				Else
					If TSFieldValueType = "" Then
						AttributeDetails = Undefined;
						TabularSectionMetadata = TabularSectionMetadata(ObjectMetadata, TabularSectionName);
						If TabularSectionMetadata <> Undefined Then
							AttributeDetails = TabularSectionAttributeMetadata(TabularSectionMetadata, TSFieldName);
							If AttributeDetails = Undefined AND Metadata.ChartsOfAccounts.Contains(ObjectMetadata) Then
								AttributeDetails = ObjectMetadata.ExtDimensionAccountingFlags.Find(TSFieldName);
							EndIf;
							If AttributeDetails <> Undefined
								AND AttributeDetails.Type.Types().Count() = 1 Then
									TSFieldValueType = AttributeDetails.Type.Types()[0];
							EndIf;
						EndIf;
					EndIf;
					LastRow = TabularSections[TabularSectionName].Get(TabularSections[TabularSectionName].Count()-1);
					LastRow[TSFieldName] = ?(ValueIsFilled(TSFieldValueType), XMLValue(TSFieldValueType, XMLReader.Value), XMLReader.Value);
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	// Exclude tabular sections from the attribute list
	For Each Item In TabularSections Do
		AttributeValues.Delete(AttributeValues.Find(Item.Key));
	EndDo;
	
	// If the object tabular section is empty and column names are not read in, fill the table columns.
	For Each TabularSection In TabularSections Do
		TableName = TabularSection.Key;
		Table = TabularSection.Value;
		If Table.Columns.Count() = 0 Then
			TableMetadata = TabularSectionMetadata(ObjectMetadata, TableName);
			If TableMetadata <> Undefined Then
				For Each ColumnDetails In TabularSectionAttributes(TableMetadata) Do
					If Table.Columns.Find(ColumnDetails.Name)= Undefined Then
						Table.Columns.Add(ColumnDetails.Name);
					EndIf;
				EndDo;
				If Metadata.ChartsOfAccounts.Contains(ObjectMetadata) Then
					For Each ColumnDetails In ObjectMetadata.ExtDimensionAccountingFlags Do
						If Table.Columns.Find(ColumnDetails.Name)= Undefined Then
							Table.Columns.Add(ColumnDetails.Name);
						EndIf;
					EndDo;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	Result.Insert("Attributes", AttributeValues);
	Result.Insert("TabularSections", TabularSections);
	
	If Result.HiddenAttributes <> Undefined Then
		For Each AttributeName In Result.HiddenAttributes Do
			If StrEndsWith(AttributeName, ".*") Then
				TabularSectionName = Left(AttributeName, StrLen(AttributeName) - 2);
				If Result.TabularSections[TabularSectionName] <> Undefined Then
					Result.TabularSections.Delete(TabularSectionName);
				EndIf;
			Else
				FoundAttributes = Result.Attributes.FindRows(New Structure("AttributeDescription", AttributeName));
				For Each Attribute In FoundAttributes Do
					Result.Attributes.Delete(Attribute);
				EndDo;
			EndIf;
		EndDo;
	EndIf;
	
	If Result.AdditionalAttributes <> Undefined Then
		For Each AdditionalAttribute In Result.AdditionalAttributes Do
			Attribute = AttributeValues.Add();
			Attribute.AttributeDescription = AdditionalAttribute.Description;
			Attribute.AttributeValue = AdditionalAttribute.Value;
			Attribute.Type = TypeOf(AdditionalAttribute.Value);
		EndDo;
	EndIf;
	
	Return Result;
	
EndFunction

Function AttributeMetadata(ObjectMetadata, AttributeName)
	Result = ObjectMetadata.Attributes.Find(AttributeName);
	If Result = Undefined Then
		Try
			Result = ObjectMetadata.StandardAttributes[AttributeName];
		Except
			Result = Undefined;
		EndTry;
	EndIf;
	Return Result;
EndFunction

Function TabularSectionMetadata(ObjectMetadata, TabularSectionName) Export
	Result = ObjectMetadata.TabularSections.Find(TabularSectionName);
	If Result = Undefined Then
		Try
			Result = ObjectMetadata.StandardTabularSections[TabularSectionName];
		Except
			Result = Undefined;
		EndTry;
	EndIf;
	Return Result;
EndFunction

Function TabularSectionAttributeMetadata(TabularSectionMetadata, AttributeName) Export
	Result = Undefined;
	If TypeOf(TabularSectionMetadata) = Type("StandardTabularSectionDescription") Then
		Try
			Result = TabularSectionMetadata.StandardAttributes[AttributeName];
		Except
			Result = Undefined;
		EndTry;
	Else
		Result = TabularSectionMetadata.Attributes.Find(AttributeName);
	EndIf;
	Return Result;
EndFunction

Function TabularSectionAttributes(TabularSectionMetadata)
	If TypeOf(TabularSectionMetadata) = Type("StandardTabularSectionDescription") Then
		Result = TabularSectionMetadata.StandardAttributes;
	Else
		Result = TabularSectionMetadata.Attributes;
	EndIf;
	Return Result;
EndFunction

Procedure GenerateObjectVersionReport(SpreadsheetDocument, ObjectDetails, ObjectRef)
	
	If ObjectRef.Metadata().Templates.Find("ObjectTemplate") <> Undefined Then
		Template = Common.ObjectManagerByRef(ObjectRef).GetTemplate("ObjectTemplate");
	Else
		Template = Undefined;
	EndIf;
	
	If Template = Undefined Then
		Section = SpreadsheetDocument.GetArea("R2");
		OutputTextToReport(SpreadsheetDocument, Section, "R2C2", ObjectRef.Metadata().Synonym, 16, True);
		
		SpreadsheetDocument.Area("C2").ColumnWidth = 30;
		If ObjectDetails.VersionNumber <> 0 Then
			OutputHeaderForVersion(SpreadsheetDocument, ObjectDetails.Details, 4, 3);
			OutputHeaderForVersion(SpreadsheetDocument, ObjectDetails.Comment, 5, 3);
		EndIf;
		
		DisplayedRowNumber = OutputParsedObjectAttributes(SpreadsheetDocument, ObjectDetails, ObjectRef);
		OutputParsedObjectTabularSections(SpreadsheetDocument, ObjectDetails, DisplayedRowNumber + 7, ObjectRef);
		OutputParsedObjectSpreadsheetDocuments(SpreadsheetDocument, ObjectDetails);
	Else
		UseStandardTemplateToGenerate(SpreadsheetDocument, Template, ObjectDetails, ObjectDetails.Details, ObjectRef);
	EndIf;
	
EndProcedure

Procedure UseStandardTemplateToGenerate(ReportTS, Template, ObjectVersion, Val VersionDetails, ObjectRef)
	
	ObjectMetadata = ObjectRef.Metadata();
	
	ObjectDescription = ObjectMetadata.Name;
	
	ReportTS = New SpreadsheetDocument;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(ObjectRef)) Then
		Template = Catalogs[ObjectDescription].GetTemplate("ObjectTemplate");
	Else
		Template = Documents[ObjectDescription].GetTemplate("ObjectTemplate");
	EndIf;
	
	// Header
	Area = Template.GetArea("Title");
	ReportTS.Put(Area);
	
	Area = ReportTS.GetArea("R3");
	SetTextProperties(Area.Area("R1C2"), VersionDetails, , True);
	ReportTS.Put(Area);
	
	Area = ReportTS.GetArea("R5");
	ReportTS.Put(Area);
	
	// Header
	Header = Template.GetArea("Header");
	Attributes = New Structure;
	For Each AttributeDetails In ObjectVersion.Attributes Do
		AttributeName = AttributeDetails.AttributeDescription;
		AttributeMetadata = AttributeMetadata(ObjectMetadata, AttributeDetails.AttributeDescription);
		If AttributeMetadata = Undefined AND Metadata.ChartsOfAccounts.Contains(ObjectMetadata) Then
			AttributeMetadata = ObjectMetadata.AccountingFlags.Find(AttributeDetails.AttributeDescription);
		EndIf;
		If AttributeMetadata <> Undefined Then
			AttributeName = AttributeMetadata.Name;
		EndIf;
		
		AttributeValue = AttributeDetails.AttributeValue;
		Attributes.Insert(AttributeName, AttributeValue);
	EndDo;
	Header.Parameters.Fill(Attributes);
	ReportTS.Put(Header);
	
	TabularSectionNames = New Array;
	For Each TabularSection In ObjectMetadata.TabularSections Do
		TabularSectionNames.Add(TabularSection.Name);
	EndDo;
	If Metadata.ChartsOfAccounts.Contains(ObjectMetadata) Then
		For Each TabularSection In ObjectMetadata.StandardTabularSections Do
			TabularSectionNames.Add(TabularSection.Name);
		EndDo;
	EndIf;
	
	For Each TabularSectionName In TabularSectionNames Do
		If ObjectVersion.TabularSections[TabularSectionName].Count() = 0 Then
			Continue;
		EndIf;
		
		TabularSection = ObjectVersion.TabularSections[TabularSectionName].Copy();
		TabularSection.Columns.Add("LineNumber");
		
		AreaName = TabularSectionName + "Header";
		If Template.Areas.Find(AreaName) <> Undefined Then
			Area = Template.GetArea(AreaName);
		Else
			Continue;
		EndIf;
		ReportTS.Put(Area);
		
		AreaName = TabularSectionName;
		If Template.Areas.Find(AreaName) <> Undefined Then
			Area = Template.GetArea(AreaName);
		Else
			Continue;
		EndIf;
		RowNumber = 0;
		For Each TableRow In TabularSection Do
			RowNumber = RowNumber + 1;
			TableRow.LineNumber = RowNumber;
			Area.Parameters.Fill(TableRow);
			ReportTS.Put(Area);
		EndDo;
	EndDo;
	
	If ObjectVersion.Property("SpreadsheetDocuments") Then
		SpreadsheetDocuments = ObjectVersion.SpreadsheetDocuments;
		If SpreadsheetDocuments <> Undefined Then
			If Template.Areas.Find("SpreadsheetDocumentsHeader") <> Undefined Then
				SpreadsheetDocumentsHeader = Template.GetArea("SpreadsheetDocumentsHeader");
				ReportTS.Put(SpreadsheetDocumentsHeader);
				SpreadsheetDocumentHeader = ?(Template.Areas.Find("SpreadsheetDocumentHeader") = Undefined,
					Undefined, Template.GetArea("SpreadsheetDocumentHeader"));
				
				For Each StructureItem In SpreadsheetDocuments Do
					If SpreadsheetDocumentHeader <> Undefined Then
						SpreadsheetDocumentDescription = New Structure("SpreadsheetDocumentDescription", StructureItem.Value.Description);
						SpreadsheetDocumentHeader.Parameters.Fill(SpreadsheetDocumentDescription);
						ReportTS.Put(SpreadsheetDocumentHeader);
					EndIf;
					ReportTS.Put(StructureItem.Value.Data);
				EndDo;
			EndIf;
		EndIf;
	EndIf;
	
	ReportTS.ShowGrid = False;
	ReportTS.Protection = True;
	ReportTS.ReadOnly = True;
	ReportTS.ShowHeaders = False;
	
EndProcedure

// Displays header of the object version report.
//
Procedure OutputHeaderForVersion(ReportTS, Val Text, Val RowNumber, Val ColumnNumber)
	
	If Not IsBlankString(Text) Then
		
		ReportTS.Area("C"+String(ColumnNumber)).ColumnWidth = 50;
		
		State = "R" + Format(RowNumber, "NG=0") + "C" + Format(ColumnNumber, "NG=0");
		ReportTS.Area(State).Text = Text;
		ReportTS.Area(State).BackColor = StyleColors.InaccessibleCellTextColor;
		ReportTS.Area(State).Font = New Font(, 8, True, , , );
		ReportTS.Area(State).TopBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
		ReportTS.Area(State).BottomBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
		ReportTS.Area(State).LeftBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
		ReportTS.Area(State).RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
		
	EndIf;
	
EndProcedure

// Displays the modified attributes in report  and gets their presentation.
//
Function OutputParsedObjectAttributes(ReportTS, ObjectVersion, ObjectRef)
	
	Section = ReportTS.GetArea("R6");
	OutputTextToReport(ReportTS, Section, "R1C1:R1C3", " ");
	OutputTextToReport(ReportTS, Section, "R1C2", "Attributes", 11, True);
	ReportTS.StartRowGroup("AttributeGroup");
	OutputTextToReport(ReportTS, Section, "R1C1:R1C3", " ");
	
	NumberOfRowsToOutput = 0;
	
	Attributes = ObjectVersion.Attributes.Copy();
	Attributes.Columns.Add("DescriptionDetailsStructure");
	Attributes.Columns.Add("DisplayedDescription");
	For Each Attribute In Attributes Do
		Attribute.DescriptionDetailsStructure = DisplayedAttributeDescription(ObjectRef, Attribute.AttributeDescription);
		Attribute.DisplayedDescription = Attribute.DescriptionDetailsStructure.DisplayedDescription;
	EndDo;
	Attributes.Sort("DisplayedDescription");
	
	For Each ItemAttribute In Attributes Do
		DescriptionDetailsStructure = ItemAttribute.DescriptionDetailsStructure;
		If Not DescriptionDetailsStructure.OutputAttribute Then
			Continue;
		EndIf;
		
		DisplayedDescription = DescriptionDetailsStructure.DisplayedDescription;
		AttributeDetails = DescriptionDetailsStructure.AttributeDetails;
		
		AttributeValue = ?(ItemAttribute.AttributeValue = Undefined, "", ItemAttribute.AttributeValue);
		ValuePresentation = AttributeValuePresentation(AttributeValue, AttributeDetails);
		
		SetTextProperties(Section.Area("R1C2"), DisplayedDescription, , True);
		SetTextProperties(Section.Area("R1C3"), ValuePresentation);
		Section.Area("R1C2:R1C3").BottomBorder = New Line(SpreadsheetDocumentCellLineType.Solid, 1, 0);
		Section.Area("R1C2:R1C3").BorderColor = StyleColors.InaccessibleCellTextColor;
		
		ReportTS.Put(Section);
		
		NumberOfRowsToOutput = NumberOfRowsToOutput + 1;
	EndDo;
	
	ReportTS.EndRowGroup();
	
	Return NumberOfRowsToOutput;
	
EndFunction

// Displays tabular sections of the parsed object (in case of a single object report).
//
Procedure OutputParsedObjectTabularSections(ReportTS, ObjectVersion, OutputRowNumber, ObjectRef)
	
	If ObjectVersion.TabularSections.Count() = 0 Then
		Return;
	EndIf;
	
	ObjectMetadata = ObjectRef.Metadata();
	NumberOfRowsToOutput = 0;
	
	For Each StringTabularSection In ObjectVersion.TabularSections Do
		TabularSectionDescription = StringTabularSection.Key;
		TabularSection             = StringTabularSection.Value;
		If TabularSection.Count() = 0 Then
			Continue;
		EndIf;
			
		TSMetadata = TabularSectionMetadata(ObjectMetadata, TabularSectionDescription);
		TSSynonym = TabularSectionDescription;
		If TSMetadata <> Undefined Then
			TSSynonym = TSMetadata.Presentation();
		EndIf;
		
		Section = ReportTS.GetArea("R" + String(OutputRowNumber));
		OutputTextToReport(ReportTS, Section, "R1C1:R1C100", " ");
		OutputArea = OutputTextToReport(ReportTS, Section, "R1C2", TSSynonym, 11, True);
		ReportTS.Area("R" + Format(OutputArea.Top, "NG=0") + "C2").CreateFormatOfRows();
		ReportTS.Area("R" + Format(OutputArea.Top, "NG=0") + "C2").ColumnWidth = Round(StrLen(TSSynonym)*2, 0, RoundMode.Round15as20);
		ReportTS.StartRowGroup("LinesGroup");
		
		OutputTextToReport(ReportTS, Section, "R1C1:R1C3", " ");
		NumberOfRowsToOutput = NumberOfRowsToOutput + 1;
		OutputRowNumber = OutputRowNumber + 3;
		
		TSToAdd = New SpreadsheetDocument;
		TSToAdd.Join(GenerateEmptySector(TabularSection.Count()+1));
		
		ColumnNumber = 2;
		ColumnDimensionMap = New Map;
		
		Section = New SpreadsheetDocument;
		SectionArea = Section.Area("R1C1");
		SetTextProperties(SectionArea, "N", , True, True);
		SectionArea.BackColor = StyleColors.InaccessibleCellTextColor;
		
		RowNumber = 1;
		For Each TabularSectionRow In TabularSection Do
			RowNumber = RowNumber + 1;
			SetTextProperties(Section.Area("R" + Format(RowNumber, "NG=0") + "C1"), Format(RowNumber-1, "NG=0"), , False, True);
		EndDo;
		TSToAdd.Join(Section);
		
		ColumnNumber = 3;
		
		For Each TabularSectionColumn In TabularSection.Columns Do
			Section = New SpreadsheetDocument;
			FieldDescription = TabularSectionColumn.Name;
			
			FieldDetails = Undefined;
			If TSMetadata <> Undefined Then
				FieldDetails = TabularSectionAttributeMetadata(TSMetadata, FieldDescription);
			EndIf;
			If FieldDetails = Undefined AND Metadata.ChartsOfAccounts.Contains(ObjectMetadata) Then
				FieldDetails = ObjectMetadata.ExtDimensionAccountingFlags.Find(FieldDescription);
			EndIf;
			If FieldDetails = Undefined Then
				DisplayedFieldDescription = FieldDescription;
			Else
				DisplayedFieldDescription = FieldDetails.Presentation();
			EndIf;
			
			ColumnHeaderColor = ?(FieldDetails = Undefined, StyleColors.DeletedAttributeTitleBackground, StyleColors.InaccessibleCellTextColor);
			AreaSection = Section.Area("R1C1");
			SetTextProperties(AreaSection, DisplayedFieldDescription, , True, True);
			AreaSection.BackColor = ColumnHeaderColor;
			ColumnDimensionMap.Insert(ColumnNumber, StrLen(FieldDescription) + 4);
			RowNumber = 1;
			For Each TabularSectionRow In TabularSection Do
				RowNumber = RowNumber + 1;
				Value = ?(TabularSectionRow[FieldDescription] = Undefined, "", TabularSectionRow[FieldDescription]);
				ValuePresentation = AttributeValuePresentation(Value, FieldDetails);
				
				SetTextProperties(Section.Area("R" + Format(RowNumber, "NG=0") + "C1"), ValuePresentation, , , True);
				If StrLen(ValuePresentation) > (ColumnDimensionMap[ColumnNumber] - 4) Then
					ColumnDimensionMap[ColumnNumber] = StrLen(ValuePresentation) + 4;
				EndIf;
			EndDo;
			
			TSToAdd.Join(Section);
			ColumnNumber = ColumnNumber + 1;
		EndDo;
		
		OutputArea = ReportTS.Put(TSToAdd);
		ReportTS.Area(OutputArea.Top, 1, OutputArea.Bottom, ColumnNumber).CreateFormatOfRows();
		ReportTS.Area("R" + Format(OutputArea.Top, "NG=0") + "C2").ColumnWidth = 7;
		For CurrentColumnNumber = 3 To ColumnNumber-1 Do
			ReportTS.Area("R" + Format(OutputArea.Top, "NG=0") + "C" + Format(CurrentColumnNumber, "NG=0")).ColumnWidth = ColumnDimensionMap[CurrentColumnNumber];
		EndDo;
		ReportTS.EndRowGroup();
	EndDo;
	
EndProcedure

// Displays text in the spreadsheet document area using specific appearance.
//
Function OutputTextToReport(ReportTable, Val Section, Val State, Val Text, Val Size = 9, Val Bold = False)
	
	SectionArea = Section.Area(State);
	
	If TypeOf(SectionArea) = Type("SpreadsheetDocumentRange") Then
	
		SectionArea.Text      = Text;
		SectionArea.Font      = New Font(, Size, Bold, , , );
		SectionArea.HorizontalAlign = HorizontalAlign.Left;
		
		SectionArea.TopBorder = New Line(SpreadsheetDocumentCellLineType.None);
		SectionArea.BottomBorder  = New Line(SpreadsheetDocumentCellLineType.None);
		SectionArea.LeftBorder  = New Line(SpreadsheetDocumentCellLineType.None);
		SectionArea.RightBorder = New Line(SpreadsheetDocumentCellLineType.None);
		
	EndIf;
	
	Return ReportTable.Put(Section);
	
EndFunction

// Displays text with conditional appearance in the spreadsheet document area.
// 
//
Procedure SetTextProperties(SectionArea, Text, Val Size = 9, Val Bold = False, Val ShowBorders = False)
	
	If TypeOf(SectionArea) = Type("SpreadsheetDocumentRange") Then
	
		SectionArea.Text = Text;
		SectionArea.Font = New Font(, Size, Bold, , , );
		
		If ShowBorders Then
			SectionArea.TopBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
			SectionArea.BottomBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
			SectionArea.LeftBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
			SectionArea.RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
			SectionArea.HorizontalAlign = HorizontalAlign.Center;
		EndIf;
	
	EndIf
	
EndProcedure

// Generates an empty sector for report output. Used if the row was not changed in any version.
// 
//
Function GenerateEmptySector(Val StringsCount, Val OutputType = "")
	
	FillingValue = New Array;
	
	For Index = 1 To StringsCount Do
		FillingValue.Add(" ");
	EndDo;
	
	Return GenerateTSRowSector(FillingValue, OutputType);
	
EndFunction

// FillingValue - a string array.
// OutputType - string :
//           "m" - modify
//           "a" - add
//           "d" - delete
//           "" - regular output.
Function GenerateTSRowSector(Val FillingValue,Val OutputType = "")
	
	CommonTemplate = InformationRegisters.ObjectsVersions.GetTemplate("StandardObjectPresentationTemplate");
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	If      OutputType = ""  Then
		Template = CommonTemplate.GetArea("InitialAttributeValue");
	ElsIf OutputType = "AND" Then
		Template = CommonTemplate.GetArea("ModifiedAttributeValue");
	ElsIf OutputType = "A" Then
		Template = CommonTemplate.GetArea("AddedAttribute");
	ElsIf OutputType = "U" Then
		Template = CommonTemplate.GetArea("DeletedAttribute");
	EndIf;
	
	For Each NextValue In FillingValue Do
		Template.Parameters.AttributeValue = NextValue;
		SpreadsheetDocument.Put(Template);
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

Function AttributeValuePresentation(AttributeValue, MetadataObjectAttribute)
	
	FormatString = "";
	If MetadataObjectAttribute <> Undefined Then
		If TypeOf(AttributeValue) = Type("Date") Then
			FormatString = "DLF=DT";
			If MetadataObjectAttribute.Type.DateQualifiers.DateFractions = DateFractions.Date Then
				FormatString = "DLF=D";
			ElsIf MetadataObjectAttribute.Type.DateQualifiers.DateFractions = DateFractions.Time Then
				FormatString = "DLF=T";
			EndIf;
		EndIf;
	EndIf;
	
	Return Format(AttributeValue, FormatString);
	
EndFunction

Function ParseVersion(Ref, VersionNumber) Export
	
	VersionInfo = ObjectVersionInfo(Ref, VersionNumber);
	
	Result = XMLObjectPresentationParsing(VersionInfo.ObjectVersion, Ref);
	Result.Insert("ObjectName",     String(Ref));
	Result.Insert("ChangeAuthor", TrimAll(String(VersionInfo.VersionAuthor)));
	Result.Insert("ChangeDate",  VersionInfo.VersionDate);
	Result.Insert("Comment",    VersionInfo.Comment);
	
	ObjectsVersioningOverridable.AfterParsingObjectVersion(Ref, Result);
	
	Return Result;
	
EndFunction

// Displays spreadsheet documents of the parsed object (in case of a single object report).
Procedure OutputParsedObjectSpreadsheetDocuments(SpreadsheetDocument, ObjectDetails)
	
	SpreadsheetDocuments = ObjectDetails.SpreadsheetDocuments;
	
	If SpreadsheetDocuments = Undefined Then
		Return;
	EndIf;
	
	CommonTemplate = InformationRegisters.ObjectsVersions.GetTemplate("StandardObjectPresentationTemplate");
	
	TemplateHeaderSpreadsheetDocuments = CommonTemplate.GetArea("SpreadsheetDocumentsHeader");	
	TemplateRowSpreadsheetDocuments = CommonTemplate.GetArea("SpreadsheetDocumentHeader");
	TemplateEmptyRow = CommonTemplate.GetArea("EmptyRow");
	
	SpreadsheetDocument.Put(TemplateEmptyRow);
	SpreadsheetDocument.Put(TemplateHeaderSpreadsheetDocuments);
	SpreadsheetDocument.Put(TemplateEmptyRow);
	SpreadsheetDocument.StartRowGroup("SpreadsheetDocumentsGroup");
	
	For Each StructureItem In SpreadsheetDocuments Do
		SpreadsheetDocumentDescription = StructureItem.Value.Description;
		TemplateRowSpreadsheetDocuments.Parameters.SpreadsheetDocumentDescription = SpreadsheetDocumentDescription;
		SpreadsheetDocument.Put(TemplateRowSpreadsheetDocuments);
		SpreadsheetDocument.Put(TemplateEmptyRow);
		
		DisplayedDocument = StructureItem.Value.Data;
		SpreadsheetDocumentDisplayArea = SpreadsheetDocument.Put(DisplayedDocument);
		SpreadsheetDocumentDisplayArea.CreateFormatOfRows();
		
		For ColumnNumber = 1 To DisplayedDocument.TableWidth Do 
			ColumnWidth = DisplayedDocument.Area(1, ColumnNumber, DisplayedDocument.TableHeight, ColumnNumber).ColumnWidth;
			SpreadsheetDocument.Area(SpreadsheetDocumentDisplayArea.Top, ColumnNumber,
				SpreadsheetDocumentDisplayArea.Bottom, ColumnNumber).ColumnWidth = ColumnWidth;
		EndDo;
		
		SpreadsheetDocument.Put(TemplateEmptyRow);
	EndDo;
	
	SpreadsheetDocument.EndRowGroup();
	SpreadsheetDocument.Put(TemplateEmptyRow);
	
EndProcedure

Function DisplayedAttributeDescription(ObjectRef, Val AttributeName) Export
	
	OutputAttribute = True;
	
	AttributeDetails = AttributeMetadata(ObjectRef.Metadata(), AttributeName);
	If AttributeDetails = Undefined Then
		AttributeDetails = Metadata.CommonAttributes.Find(AttributeName);
	EndIf;
	
	AttributePresentation = AttributeName;
	If AttributeDetails <> Undefined Then
		AttributePresentation = AttributeDetails.Presentation();
	EndIf;
	
	ObjectsVersioningOverridable.OnDetermineObjectAttributeDescription(ObjectRef, 
		AttributeName, AttributePresentation, OutputAttribute);
	
	Return New Structure("DisplayedDescription, OutputAttribute, AttributeDetails", 
		AttributePresentation, OutputAttribute, AttributeDetails);
	
EndFunction

Function DataToStore(Val Object)
	
	ObjectRef = Object;
	If Common.RefTypeValue(Object) Then
		Object = Object.GetObject();
	Else
		ObjectRef = Object.Ref;
	EndIf;
	
	ObjectData = SerializeObject(Object);
	
	SpreadsheetDocuments = ObjectSpreadsheetDocuments(ObjectRef);
	
	AdditionalAttributes = AdditionalAttributesCollection();
	HiddenAttributes = HiddenAttributesCollection();
	
	ObjectsVersioningOverridable.OnPrepareObjectData(Object, AdditionalAttributes);
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.OnPrepareObjectData(Object, AdditionalAttributes);
		HiddenAttributes.Add("AdditionalAttributes.*");
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManagerInternal = Common.CommonModule("ContactsManagerInternal");
		ModuleContactsManagerInternal.OnPrepareObjectData(Object, AdditionalAttributes);
		HiddenAttributes.Add("ContactInformation.*");
	EndIf;
	
	ObjectManager = Common.ObjectManagerByRef(ObjectRef);
	Settings = SubsystemSettings();
	Try
		ObjectManager.OnDefineObjectVersioningSettings(Settings);
	Except
		Settings = SubsystemSettings();
	EndTry;
	
	ObjectInternalAttributes = New Array;
	If Settings.OnGetInternalAttributes Then
		ObjectManager.OnGetInternalAttributes(ObjectInternalAttributes);
		CommonClientServer.SupplementArray(HiddenAttributes, ObjectInternalAttributes);
	EndIf;
	CommonClientServer.SupplementArray(HiddenAttributes, ObjectsInternalAttributes());
	
	Result = New Structure;
	
	If SpreadsheetDocuments <> Undefined AND SpreadsheetDocuments.Count() > 0 Then
		Result.Insert("SpreadsheetDocuments", SpreadsheetDocuments);
	EndIf;
	
	If AdditionalAttributes.Count() > 0 Then
		Result.Insert("AdditionalAttributes", AdditionalAttributes);
	EndIf;
	
	If HiddenAttributes.Count() > 0 Then
		Result.Insert("HiddenAttributes", HiddenAttributes);
	EndIf;
	
	If Result.Count() > 0 Then
		Result.Insert("Object", ObjectData);
	Else
		Result = ObjectData;
	EndIf;
	
	Return Result;
	
EndFunction

Function AdditionalAttributesCollection()
	Result = New ValueTable;
	Result.Columns.Add("ID");
	Result.Columns.Add("Description", New TypeDescription("String"));
	Result.Columns.Add("Value");
	
	Return Result;
EndFunction

Function HiddenAttributesCollection()
	Return New Array;
EndFunction

Function ObjectSpreadsheetDocuments(Ref)
	Result = New Structure;
	ObjectsVersioningOverridable.OnReceiveObjectSpreadsheetDocuments(Ref, Result);
	Return Result;
EndFunction

Function ObjectsInternalAttributes()
	Attributes = New Array;
	Attributes.Add("Ref");
	Attributes.Add("IsFolder");
	Attributes.Add("PredefinedDataName");
	
	Return Attributes;
EndFunction

Function DataSize(Data) Export
	Return Base64Value(XDTOSerializer.XMLString(Data)).Size();
EndFunction

Procedure AddInfoAboutNode(Record, Recipient)
	
	If Record.Node = Common.SubjectString(Recipient.Ref) Then
		Record.Node = "";
	Else
		If IsBlankString(Record.Node) Then
			ExchangePlanManager = Common.ObjectManagerByRef(Recipient.Ref);
			Record.Node = Common.SubjectString(ExchangePlanManager.ThisNode());
		EndIf;
	EndIf;
	
	If Record.VersionAuthor = Undefined Then
		Return;
	EndIf;
	AuthorMetadata = Record.VersionAuthor.Metadata();
	If Common.IsExchangePlan(AuthorMetadata) Then
		Record.Comment = StringFunctionsClientServer.SubstituteParametersToString("<VersionAuthor>%1;%2</VersionAuthor>",
			AuthorMetadata.Name, Common.ObjectAttributeValue(Record.VersionAuthor, "Code"))
			+ Record.Comment;
	EndIf;
	
EndProcedure

Procedure ReadInfoAboutNode(Record)
	
	If StrStartsWith(Record.Comment, "<VersionAuthor>") Then
		Position = StrFind(Record.Comment, "</VersionAuthor>");
		If Position > 0 Then
			NodeDetails = Left(Record.Comment, Position - 1);
			Record.Comment = Mid(Record.Comment, Position + StrLen("</VersionAuthor>"));
			NodeDetails = Mid(NodeDetails, StrLen("<VersionAuthor>") + 1);
			NodeDetails = StrSplit(NodeDetails, ";");
			NodeName = NodeDetails[0];
			NodeCode = NodeDetails[1];
			VersionAuthor = ExchangePlans[NodeName].FindByCode(NodeCode);
			If ValueIsFilled(VersionAuthor) Then
				Record.VersionAuthor = VersionAuthor;
			EndIf;
		EndIf;
	EndIf;
	
	If Record.VersionAuthor = Undefined Then
		Return;
	EndIf;
	AuthorMetadata = Record.VersionAuthor.Metadata();
	
	If Common.IsExchangePlan(AuthorMetadata) Then
		ExchangePlanManager = Common.ObjectManagerByRef(Record.VersionAuthor);
		If Record.VersionAuthor = ExchangePlanManager.ThisNode() Then
			Record.Node = "";
		EndIf;
	EndIf;
	
EndProcedure

Function VersionsToExport(Object, Node)
	
	QueryText =
	"SELECT
	|	ChangeObjectsVersions.VersionNumber AS VersionNumber
	|FROM
	|	InformationRegister.ObjectsVersions.Changes AS ChangeObjectsVersions
	|		INNER JOIN InformationRegister.ObjectsVersions AS ObjectsVersions
	|		ON ChangeObjectsVersions.Object = ObjectsVersions.Object
	|			AND ChangeObjectsVersions.VersionNumber = ObjectsVersions.VersionNumber
	|WHERE
	|	ChangeObjectsVersions.Object = &Object
	|	AND ChangeObjectsVersions.Node = &Node
	|
	|ORDER BY
	|	VersionNumber DESC";
	
	Query = New Query(QueryText);
	Query.SetParameter("Object", Object);
	Query.SetParameter("Node", Node);
	
	Return Query.Execute().Unload();
	
EndFunction

Function SubsystemSettings()
	Result = New Structure;
	Result.Insert("OnGetInternalAttributes", False);
	
	Return Result;
EndFunction

Function NumberOfUnsynchronizedVersions(Object)
	
	QueryText = 
	"SELECT
	|	COUNT(1) AS Count
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	NOT ObjectsVersions.Synchronized
	|	AND ObjectsVersions.Object = &Object";
	
	Query = New Query(QueryText);
	Query.SetParameter("Object", Object);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Count;
	EndIf;
	
	Return 0;
	
EndFunction

Function ObjectWritingInProgress(Value = Undefined)
	If Value <> Undefined Then
		SessionParameters.ObjectWritingInProgress = Value;
		Return Value;
	EndIf;
	Return SessionParameters.ObjectWritingInProgress;
EndFunction

Function VersionRegisterIsIncludedInExchangePlan(Sender)
	MetadataObject = Metadata.FindByType(TypeOf(Sender));
	Return MetadataObject.Content.Contains(Metadata.InformationRegisters.ObjectsVersions);
EndFunction

Function GoToVersionServer(Ref, VersionNumber, ErrorMessageText, UndoPosting = False) Export
	
	If Not Users.IsFullUser() Then
		Raise NStr("ru = 'Недостаточно прав для выполнения операции.'; en = 'Insufficient rights to perform the operation.'; pl = 'Niewystarczające uprawnienia do wykonania operacji.';es_ES = 'Insuficientes derechos para realizar la operación.';es_CO = 'Insuficientes derechos para realizar la operación.';tr = 'İşlem için gerekli yetkiler yok.';it = 'Autorizzazioni insufficienti per eseguire l''operazione.';de = 'Unzureichende Rechte auf Ausführen der Operation.'");
	EndIf;
	
	CustomNumberPresentation = VersionNumberInHierarchy(Ref, VersionNumber);
	Information = ObjectVersionInfo(Ref, VersionNumber);
	
	AdditionalAttributes = Undefined;
	If TypeOf(Information.ObjectVersion) = Type("Structure") Then
		If Information.ObjectVersion.Property("AdditionalAttributes", AdditionalAttributes) Then
			FoundAttributes = AdditionalAttributes.FindRows(New Structure("ID", Undefined));
			For Each Attribute In FoundAttributes Do
				AdditionalAttributes.Delete(Attribute);
			EndDo;
		EndIf;
	EndIf;
	
	ErrorMessageText = "";
	Object = RestoreObjectByXML(Information.ObjectVersion, ErrorMessageText);
	
	If Not IsBlankString(ErrorMessageText) Then
		Return "RecoveryError";
	EndIf;
	
	Object.AdditionalProperties.Insert("ObjectsVersioningVersionComment",
		StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Объект восстановлен до версии %1, созданной %2'; en = 'Object is restored to version %1 created on %2'; pl = 'Obiekt został przywrócony do wersji %1, utworzonej %2';es_ES = 'El objeto se restablece a la versión %1 creada en %2';es_CO = 'El objeto se restablece a la versión %1 creada en %2';tr = 'Nesne, %2 tarihinde oluşturulan %1 sürümüne geri yüklendi';it = 'L''oggetto è ripristinato alla versione %1 creata il %2';de = 'Objekt ist zur Version %1 erstellt am %2 wiederhergestellt'"),
			CustomNumberPresentation,
			Format(Information.VersionDate, "DLF=DT")));
			
	
	WriteMode = Undefined;
	ErrorID = "RecoveryError";
	
	If Common.IsDocument(Object.Metadata()) AND Object.Metadata().Posting = Metadata.ObjectProperties.Posting.Allow Then
		If Object.Posted AND Not UndoPosting Then
			WriteMode = DocumentWriteMode.Posting;
		Else
			WriteMode = DocumentWriteMode.UndoPosting;
		EndIf;
		ErrorID = "PostingError";
	EndIf;
	
	BeginTransaction();
	Try
		WriteCurrentVersionData(Ref);
		ObjectWritingInProgress(True);
		If ValueIsFilled(WriteMode) Then
			Object.Write(WriteMode);
		Else
			Object.Write();
		EndIf;
		If ValueIsFilled(AdditionalAttributes) Then
			If Common.SubsystemExists("StandardSubsystems.Properties") Then
				ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
				ModulePropertyManagerInternal.OnRestoreObjectVersion(Object, AdditionalAttributes);
			EndIf;
			ObjectsVersioningOverridable.OnRestoreObjectVersion(Object, AdditionalAttributes);
		EndIf;
		ObjectWritingInProgress(False);
		WriteObjectVersion(Object);
		CommitTransaction();
	Except
		RollbackTransaction();
		ObjectWritingInProgress(False);
		ErrorMessageText = BriefErrorDescription(ErrorInfo());
		Return ErrorID;
	EndTry;
	
	Return "Recovered";
	
EndFunction

Function VersionNumberInHierarchy(Ref, VersionNumber)
	
	If HasRightToReadObjectVersionData() Then
		SetPrivilegedMode(True);
	EndIf;
	
	QueryText = 
	"SELECT
	|	ObjectsVersions.VersionNumber AS VersionNumber,
	|	ObjectsVersions.VersionOwner
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.Object = &Ref
	|
	|ORDER BY
	|	VersionNumber DESC";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	
	VersionTable = Query.Execute().Unload();
	
	VersionsTree = New ValueTree;
	VersionsTree.Columns.Add("VersionNumber");
	VersionsTree.Columns.Add("VersionNumberPresentation");
	VersionsTree.Columns.Add("Rejected", New TypeDescription("Boolean"));
	
	FillVersionHierarchy(VersionsTree, VersionTable);
	NumberVersions(VersionsTree.Rows);
	
	VersionDetails = VersionsTree.Rows.Find(VersionNumber, "VersionNumber", True);
	Result = VersionDetails;
	If Result <> Undefined Then
		Result = VersionDetails.VersionNumberPresentation;
	EndIf;
	
	Return Result;
	
EndFunction

Procedure FillVersionHierarchy(VersionHierarchy, VersionList) Export
	
	SkippedVersions = New Array;
	For Each VersionDetails In VersionList Do
		If VersionDetails.VersionOwner = 0 Then
			Item = VersionHierarchy.Rows.Add();
		Else
			FoundVersion = VersionHierarchy.Rows.Find(VersionDetails.VersionOwner, "VersionNumber", True);
			If FoundVersion <> Undefined Then
				Item = FoundVersion.Rows.Add();
				FoundVersion.Rejected = True;
			Else
				SkippedVersions.Add(VersionDetails);
				Continue;
			EndIf;
		EndIf;
		FillPropertyValues(Item, VersionDetails);
	EndDo;
	
	If SkippedVersions.Count() > 0 Then
		If VersionList.Count() = SkippedVersions.Count() Then
			Return;
		EndIf;
		FillVersionHierarchy(VersionHierarchy, SkippedVersions);
	EndIf;
	
EndProcedure

Procedure NumberVersions(VersionCollection) Export
	
	VersionCurrentNumber = VersionCollection.Count();
	For Each Version In VersionCollection Do
		NumberPrefix = "";
		If Version.Parent <> Undefined AND Not IsBlankString(Version.Parent.VersionNumberPresentation) Then
			NumberPrefix = Version.Parent.VersionNumberPresentation + ".";
		EndIf;
		
		Version.VersionNumberPresentation = NumberPrefix + Format(VersionCurrentNumber, "NG=0");
		NumberVersions(Version.Rows);
		VersionCurrentNumber = VersionCurrentNumber - 1;
	EndDo;
	
EndProcedure

#EndRegion
