#Region Internal

// See AccessManagementInternal.AccessKindsProperties. 
Function AccessKindsProperties() Export
	
	AccessKindsProperties = StandardSubsystemsServer.ApplicationParameter(
		"StandardSubsystems.AccessManagement.AccessKindsProperties");
	
	If AccessKindsProperties = Undefined Then
		AccessManagementInternal.UpdateAccessKindsPropertiesDetails();
	EndIf;
	
	AccessKindsProperties = StandardSubsystemsServer.ApplicationParameter(
		"StandardSubsystems.AccessManagement.AccessKindsProperties");
	
	Return AccessKindsProperties;
	
EndFunction

// See InformationRegisters.ObjectsRightsSettings.AvailableRights. 
Function RightsForObjectsRightsSettingsAvailable() Export
	
	Return InformationRegisters.ObjectsRightsSettings.RightsForObjectsRightsSettingsAvailable();
	
EndFunction

// See Catalogs.AccessGroupsProfiles.SuppliedProfiles. 
Function SuppliedProfilesDescription() Export
	
	Return Catalogs.AccessGroupProfiles.SuppliedProfilesDescription();
	
EndFunction

// Returns the value table containing an access restriction kind for each metadata object right.
// 
//  If no record is returned for a right, no restrictions exist for this right.
//  The table contains only the access kinds specified by the developer
//  based on their usage in restriction texts.
//  To receive all access kinds including the ones used in access value sets,
// the current state of the AccessValuesSets information register can be used.
// 
//
// Parameters:
//  ForCheck - Boolean - return text description of right restrictions filled in overridable modules 
//                         without checking.
//
// Returns:
//  ValueTable - if ForCheck = False, the columns are the following:
//    Table        - String - a metadata object table name, for example, Catalog.Files.
//    Right          - String: "Read", "Update".
//    AccessKind - Ref - a blank reference of the main type of access kind values, a blank reference 
//                              of the right setting owner.
//                   - Undefined - for the Object access kind.
//    ObjectTable - Ref - a blank reference to metadata object used to set access restrictions via 
//                     access value sets, for example, Catalog.FilesFolders.
//                   - Undefined, if AccessKind <> Undefined.
//
//  String - if ForCheck = True - right restrictions, as they are added to the overridable module.
//
Function PermanentMetadataObjectsRightsRestrictionsKinds(ForCheck = False) Export
	
	SetPrivilegedMode(True);
	
	RightsAccessKinds = New ValueTable;
	RightsAccessKinds.Columns.Add("Table",        New TypeDescription("CatalogRef.MetadataObjectIDs"));
	RightsAccessKinds.Columns.Add("UserRight",          New TypeDescription("String", , New StringQualifiers(20)));
	RightsAccessKinds.Columns.Add("AccessKind",     DetailsOfAccessValuesTypesAndRightsSettingsOwners());
	RightsAccessKinds.Columns.Add("ObjectTable", Metadata.InformationRegisters.AccessValuesSets.Dimensions.Object.Type);
	
	RightsRestrictions = "";
	
	SSLSubsystemsIntegration.OnFillMetadataObjectsAccessRestrictionKinds(RightsRestrictions);
	AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionKinds(RightsRestrictions);
	
	If ForCheck Then
		Return RightsRestrictions;
	EndIf;
	
	AccessKindsByNames = AccessManagementInternalCached.AccessKindsProperties().ByNames;
	
	For RowNumber = 1 To StrLineCount(RightsRestrictions) Do
		CurrentRow = TrimAll(StrGetLine(RightsRestrictions, RowNumber));
		If ValueIsFilled(CurrentRow) Then
			ErrorNote = "";
			If StrOccurrenceCount(CurrentRow, ".") <> 3 AND StrOccurrenceCount(CurrentRow, ".") <> 5 Then
				ErrorNote = NStr("ru = 'Строка должна быть в формате ""<Полное имя таблицы>.<Имя права>.<Имя вида доступа>[.Таблица объекта]"".'; en = 'String must be in format: ""<Full table name>.<Right name>.<Access kind name>[.Object table]"".'; pl = 'Wers powinien być sformatowany jako ""<Pełna nazwa tabeli>. <Right name>.<Nazwa rodzaju dostępu> [.Tabela obiektu].""';es_ES = 'La línea tiene que estar formateada de la siguiente manera ""<Nombre completo de la tabla>.<Right name>.<Nombre del tipo de acceso>[.Tabla del objeto]"".';es_CO = 'La línea tiene que estar formateada de la siguiente manera ""<Nombre completo de la tabla>.<Right name>.<Nombre del tipo de acceso>[.Tabla del objeto]"".';tr = 'Dize ""<Tam tablo adı>. <Hak ismi>. <Erişim türü adı> [.Object tablosu]"" şeklinde biçimlendirilmelidir.';it = 'Le stringe devono essere nel formato: ""<Nome completo tabella>.<Nome permesso>.<Nome tipologia di accesso>[.Object table]"".';de = 'Die Zeichenfolge sollte wie folgt formatiert sein: ""<Vollständiger Tabellenname>. <Right name>. [. Objekttabelle]"".'");
			Else
				RightPosition = StrFind(CurrentRow, ".");
				RightPosition = StrFind(Mid(CurrentRow, RightPosition + 1), ".") + RightPosition;
				Table = Left(CurrentRow, RightPosition - 1);
				AccessKindPosition = StrFind(Mid(CurrentRow, RightPosition + 1), ".") + RightPosition;
				Right = Mid(CurrentRow, RightPosition + 1, AccessKindPosition - RightPosition - 1);
				If StrOccurrenceCount(CurrentRow, ".") = 3 Then
					AccessKind = Mid(CurrentRow, AccessKindPosition + 1);
					ObjectTable = "";
				Else
					ObjectTablePosition = StrFind(Mid(CurrentRow, AccessKindPosition + 1), ".") + AccessKindPosition;
					AccessKind = Mid(CurrentRow, AccessKindPosition + 1, ObjectTablePosition - AccessKindPosition - 1);
					ObjectTable = Mid(CurrentRow, ObjectTablePosition + 1);
				EndIf;
				
				If Metadata.FindByFullName(Table) = Undefined Then
					ErrorNote = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Не найдена таблица ""%1"".'; en = '""%1"" table is not found.'; pl = 'Tabela ""%1"" nie została znaleziona.';es_ES = 'Tabla ""%1"" no se ha encontrado.';es_CO = 'Tabla ""%1"" no se ha encontrado.';tr = 'Tablo ""%1"" bulunmadı.';it = 'Tabella ""%1"" non trovata.';de = 'Tabelle ""%1"" wurde nicht gefunden.'"), Table);
				
				ElsIf Right <> "Read" AND Right <> "Update" Then
					ErrorNote = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Не найдено право ""%1"".'; en = '""%1"" right is not found.'; pl = 'Prawo ""%1"" nie zostało znalezione';es_ES = 'Derecho ""%1"" no se ha encontrado.';es_CO = 'Derecho ""%1"" no se ha encontrado.';tr = 'Hak ""%1"" bulunmadı.';it = 'permesso ""%1"" non è stato trovato.';de = 'Recht ""%1"" wurde nicht gefunden.'"), Right);
				
				ElsIf Upper(AccessKind) = Upper("Object") Then
					If Metadata.FindByFullName(ObjectTable) = Undefined Then
						ErrorNote = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("ru = 'Не найдена таблица объекта ""%1"".'; en = '""%1"" object table is not found.'; pl = 'Nie znaleziono tabeli obiektu ""%1"".';es_ES = 'Tabla del objeto ""%1"" no se ha encontrado.';es_CO = 'Tabla del objeto ""%1"" no se ha encontrado.';tr = '""%1"" Nesne tablosu bulunamadı.';it = 'Tabella oggetto ""%1"" non trovata.';de = 'Tabelle des Objekts ""%1"" wurde nicht gefunden.'"),
							ObjectTable);
					Else
						AccessKindRef = Undefined;
						ObjectTableRef = AccessManagementInternal.MetadataObjectEmptyRef(
							ObjectTable);
					EndIf;
					
				ElsIf Upper(AccessKind) = Upper("RightsSettings") Then
					If Metadata.FindByFullName(ObjectTable) = Undefined Then
						ErrorNote = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("ru = 'Не найдена таблица владельца настроек прав ""%1"".'; en = '""%1"" right settings owner table is not found.'; pl = 'Nie znaleziono tabeli właściciela ustawień uprawnień ""%1"".';es_ES = 'Tabla del propietario de las configuraciones del derecho ""%1"" no se ha encontrado.';es_CO = 'Tabla del propietario de las configuraciones del derecho ""%1"" no se ha encontrado.';tr = 'Hak ayar sahibi ""%1"" tablosu bulunamadı.';it = 'Tabella proprietario impostazioni dei diritti ""%1"" non trovata.';de = 'Tabelle der Rechteinstellungsinhaber ""%1"" wurde nicht gefunden.'"),
							ObjectTable);
					Else
						AccessKindRef = AccessManagementInternal.MetadataObjectEmptyRef(
							ObjectTable);
						ObjectTableRef = Undefined;
					EndIf;
				
				ElsIf AccessKindsByNames.Get(AccessKind) = Undefined Then
					ErrorNote = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Не найден вид доступа ""%1"".'; en = '""%1"" access kind is not found.'; pl = 'Rodzaj dostępu ""%1"" nie został znaleziony.';es_ES = 'Tipo de acceso ""%1"" no se ha encontrado.';es_CO = 'Tipo de acceso ""%1"" no se ha encontrado.';tr = 'Erişim türü ""%1"" bulunamadı.';it = 'Tipo di accesso ""%1"" non trovato.';de = 'Zugriffsart ""%1"" wurde nicht gefunden.'"), AccessKind);
				Else
					AccessKindRef = AccessKindsByNames.Get(AccessKind).Ref;
					ObjectTableRef = Undefined;
				EndIf;
			EndIf;
			
			If ValueIsFilled(ErrorNote) Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Ошибка в строке описания вида ограничений права объекта метаданных:
						           |""%1"".'; 
						           |en = 'An error occurred in the line with right restriction kind description of metadata object:
						           |""%1"".'; 
						           |pl = 'Błąd w opisie typu ograniczeń praw obiektu metadanych: "
"%1.';
						           |es_ES = 'Error en la línea de descripción del tipo de restricciones de derechos del objeto de metadatos:
						           |""%1"".';
						           |es_CO = 'Error en la línea de descripción del tipo de restricciones de derechos del objeto de metadatos:
						           |""%1"".';
						           |tr = 'Meta veri nesnesi kısıtlama hakkı türünün açıklama satırında bir hata oluştu: 
						           |%1';
						           |it = 'Si è verificato un errore nella riga con la descrizione del tipo di restrizione dei diritti dell''oggetto di metadati:
						           |""%1"".';
						           |de = 'Fehler in der Beschreibung der Art der Einschränkung der Rechte des Metadatenobjekts:
						           |""%1"".'")
						+ Chars.LF
						+ Chars.LF,
						CurrentRow)
					+ ErrorNote;
			Else
				AccessKindProperties = AccessKindsByNames.Get(AccessKind);
				NewDetails = RightsAccessKinds.Add();
				NewDetails.Table = Common.MetadataObjectID(Table);
				NewDetails.UserRight = Right;
				NewDetails.AccessKind = AccessKindRef;
				NewDetails.ObjectTable = ObjectTableRef;
			EndIf;
		EndIf;
	EndDo;
	
	// Adding object access kinds defined not only using access value sets.
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessRightsDependencies.SubordinateTable,
	|	AccessRightsDependencies.LeadingTableType
	|FROM
	|	InformationRegister.AccessRightsDependencies AS AccessRightsDependencies";
	RightsDependencies = Query.Execute().Unload();
	
	StopAttempts = False;
	While NOT StopAttempts Do
		StopAttempts = True;
		Filter = New Structure("AccessKind", Undefined);
		AccessKindsObject = RightsAccessKinds.FindRows(Filter);
		For each Row In AccessKindsObject Do
			TableID = Common.MetadataObjectID(
				TypeOf(Row.ObjectTable));
			
			Filter = New Structure;
			Filter.Insert("SubordinateTable", Row.Table);
			Filter.Insert("LeadingTableType", Row.ObjectTable);
			If RightsDependencies.FindRows(Filter).Count() = 0 Then
				LeadingRight = Row.UserRight;
			Else
				LeadingRight = "Read";
			EndIf;
			Filter = New Structure("Table, UserRight", TableID, LeadingRight);
			LeadingTableAccessKinds = RightsAccessKinds.FindRows(Filter);
			For each AccessKindDetails In LeadingTableAccessKinds Do
				If AccessKindDetails.AccessKind = Undefined Then
					// Object access kind cannot be added.
					Continue;
				EndIf;
				Filter = New Structure;
				Filter.Insert("Table",    Row.Table);
				Filter.Insert("UserRight",      Row.UserRight);
				Filter.Insert("AccessKind", AccessKindDetails.AccessKind);
				If RightsAccessKinds.FindRows(Filter).Count() = 0 Then
					FillPropertyValues(RightsAccessKinds.Add(), Filter);
					StopAttempts = False;
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	Return RightsAccessKinds;
	
EndFunction

#EndRegion

#Region Private

// For internal use only.
Function RecordKeyDetails(TypeORFullName) Export
	
	KeyDetails = New Structure("FieldArray, FieldsString", New Array, "");
	
	If TypeOf(TypeORFullName) = Type("Type") Then
		MetadataObject = Metadata.FindByType(TypeORFullName);
	Else
		MetadataObject = Metadata.FindByFullName(TypeORFullName);
	EndIf;
	Manager = Common.ObjectManagerByFullName(MetadataObject.FullName());
	
	For each Column In Manager.CreateRecordSet().Unload().Columns Do
		
		If MetadataObject.Resources.Find(Column.Name) = Undefined
		   AND MetadataObject.Attributes.Find(Column.Name) = Undefined Then
			// If a field is not found in resources or attributes, this field is a dimension.
			KeyDetails.FieldArray.Add(Column.Name);
			KeyDetails.FieldsString = KeyDetails.FieldsString + Column.Name + ",";
		EndIf;
	EndDo;
	
	KeyDetails.FieldsString = Left(KeyDetails.FieldsString, StrLen(KeyDetails.FieldsString)-1);
	
	Return Common.FixedData(KeyDetails);
	
EndFunction

// For internal use only.
Function TableFieldTypes(FullFieldName) Export
	
	MetadataObject = Metadata.FindByFullName(FullFieldName);
	
	TypesArray = MetadataObject.Type.Types();
	
	FieldTypes = New Map;
	For each Type In TypesArray Do
		If Type = Type("CatalogObject.MetadataObjectIDs") Then
			Continue;
		EndIf;
		FieldTypes.Insert(Type, True);
	EndDo;
	
	Return New FixedMap(FieldTypes);
	
EndFunction

// Returns types of objects and references used in the specified event subscriptions.
// 
// Parameters:
//  SubscriptionsNames - String - a multiline string containing rows of the subscription name 
//                  beginning.
//
Function ObjectsTypesInSubscriptionsToEvents(SubscriptionsNames, BlankRefsArray = False) Export
	
	ObjectsTypes = New Map;
	
	For each Subscription In Metadata.EventSubscriptions Do
		
		For RowNumber = 1 To StrLineCount(SubscriptionsNames) Do
			
			NameBeginning = StrGetLine(SubscriptionsNames, RowNumber);
			SubscriptionName = Subscription.Name;
			
			If Upper(Left(SubscriptionName, StrLen(NameBeginning))) = Upper(NameBeginning) Then
				
				For each Type In Subscription.Source.Types() Do
					If Type = Type("CatalogObject.MetadataObjectIDs") Then
						Continue;
					EndIf;
					ObjectsTypes.Insert(Type, True);
				EndDo;
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If Not BlankRefsArray Then
		Return New FixedMap(ObjectsTypes);
	EndIf;
	
	Array = New Array;
	For each KeyAndValue In ObjectsTypes Do
		Array.Add(AccessManagementInternal.MetadataObjectEmptyRef(
			KeyAndValue.Key));
	EndDo;
	
	Return New FixedArray(Array);
	
EndFunction

// For internal use only.
Function BlankRecordSetTable(FullRegisterName) Export
	
	Manager = Common.ObjectManagerByFullName(FullRegisterName);
	
	Return New ValueStorage(Manager.CreateRecordSet().Unload());
	
EndFunction

// For internal use only.
Function BlankSpecifiedTypesRefsTable(FullAttributeName) Export
	
	TypesDetails = Metadata.FindByFullName(FullAttributeName).Type;
	
	BlankRefs = New ValueTable;
	BlankRefs.Columns.Add("EmptyRef", TypesDetails);
	
	For each ValueType In TypesDetails.Types() Do
		If Common.IsReference(ValueType) Then
			BlankRefs.Add().EmptyRef = Common.ObjectManagerByFullName(
				Metadata.FindByType(ValueType).FullName()).EmptyRef();
		EndIf;
	EndDo;
	
	Return New ValueStorage(BlankRefs);
	
EndFunction

// For internal use only.
Function BlankRefsMapToSpecifiedRefsTypes(FullAttributeName) Export
	
	TypesDetails = Metadata.FindByFullName(FullAttributeName).Type;
	
	BlankRefs = New Map;
	
	For each ValueType In TypesDetails.Types() Do
		If Common.IsReference(ValueType) Then
			BlankRefs.Insert(ValueType, Common.ObjectManagerByFullName(
				Metadata.FindByType(ValueType).FullName()).EmptyRef() );
		EndIf;
	EndDo;
	
	Return New FixedMap(BlankRefs);
	
EndFunction

// For internal use only.
Function RefsTypesCodes(FullAttributeName) Export
	
	TypesDetails = Metadata.FindByFullName(FullAttributeName).Type;
	
	NumericCodesOfTypes = New Map;
	CurrentCode = 0;
	
	For each ValueType In TypesDetails.Types() Do
		If Common.IsReference(ValueType) Then
			NumericCodesOfTypes.Insert(ValueType, CurrentCode);
		EndIf;
		CurrentCode = CurrentCode + 1;
	EndDo;
	
	TypesStringCodes = New Map;
	
	StringCodeLength = StrLen(Format(CurrentCode-1, "NZ=0; NG="));
	FormatCodeString = "ND=" + Format(StringCodeLength, "NZ=0; NG=") + "; NZ=0; NLZ=; NG=";
	
	For each KeyAndValue In NumericCodesOfTypes Do
		TypesStringCodes.Insert(
			KeyAndValue.Key,
			Format(KeyAndValue.Value, FormatCodeString));
	EndDo;
	
	Return New FixedMap(TypesStringCodes);
	
EndFunction

// For internal use only.
Function EnumerationsCodes() Export
	
	EnumerationsCodes = New Map;
	
	For each AccessValueType In Metadata.DefinedTypes.AccessValue.Type.Types() Do
		TypeMetadata = Metadata.FindByType(AccessValueType);
		If TypeMetadata = Undefined OR NOT Metadata.Enums.Contains(TypeMetadata) Then
			Continue;
		EndIf;
		For each EnumValue In TypeMetadata.EnumValues Do
			ValueName = EnumValue.Name;
			EnumerationsCodes.Insert(Enums[TypeMetadata.Name][ValueName], ValueName);
		EndDo;
	EndDo;
	
	Return New FixedMap(EnumerationsCodes);;
	
EndFunction

// For internal use only.
Function AccessKindsGroupsAndValuesTypes() Export
	
	AccessKindsProperties = AccessManagementInternalCached.AccessKindsProperties();
	
	AccessKindsGroupsAndValuesTypes = New ValueTable;
	AccessKindsGroupsAndValuesTypes.Columns.Add("AccessKind",        Metadata.DefinedTypes.AccessValue.Type);
	AccessKindsGroupsAndValuesTypes.Columns.Add("GroupAndValueType", Metadata.DefinedTypes.AccessValue.Type);
	
	For each KeyAndValue In AccessKindsProperties.ByGroupsAndValuesTypes Do
		Row = AccessKindsGroupsAndValuesTypes.Add();
		Row.AccessKind = KeyAndValue.Value.Ref;
		
		Types = New Array;
		Types.Add(KeyAndValue.Key);
		TypeDetails = New TypeDescription(Types);
		
		Row.GroupAndValueType = TypeDetails.AdjustValue(Undefined);
	EndDo;
	
	Return AccessKindsGroupsAndValuesTypes;
	
EndFunction

// For internal use only.
Function DetailsOfAccessValuesTypesAndRightsSettingsOwners() Export
	
	Types = New Array;
	For Each Type In Metadata.DefinedTypes.AccessValue.Type.Types() Do
		Types.Add(Type);
	EndDo;
	
	For Each Type In Metadata.DefinedTypes.RightsSettingsOwner.Type.Types() Do
		If Type = Type("String") Then
			Continue;
		EndIf;
		Types.Add(Type);
	EndDo;
	
	Return New TypeDescription(Types);
	
EndFunction

// For internal use only.
Function ValuesTypesOfAccessKindsAndRightsSettingsOwners() Export
	
	ValuesTypesOfAccessKindsAndRightsSettingsOwners = New ValueTable;
	
	ValuesTypesOfAccessKindsAndRightsSettingsOwners.Columns.Add("AccessKind",
		AccessManagementInternalCached.DetailsOfAccessValuesTypesAndRightsSettingsOwners());
	
	ValuesTypesOfAccessKindsAndRightsSettingsOwners.Columns.Add("ValuesType",
		AccessManagementInternalCached.DetailsOfAccessValuesTypesAndRightsSettingsOwners());
	
	AccessKindsValuesTypes = AccessKindsValuesTypes();
	
	For each Row In AccessKindsValuesTypes Do
		FillPropertyValues(ValuesTypesOfAccessKindsAndRightsSettingsOwners.Add(), Row);
	EndDo;
	
	AvailableRights = AccessManagementInternalCached.RightsForObjectsRightsSettingsAvailable();
	RightsOwners = AvailableRights.ByRefsTypes;
	
	For each KeyAndValue In RightsOwners Do
		
		Types = New Array;
		Types.Add(KeyAndValue.Key);
		TypeDetails = New TypeDescription(Types);
		
		Row = ValuesTypesOfAccessKindsAndRightsSettingsOwners.Add();
		Row.AccessKind  = TypeDetails.AdjustValue(Undefined);
		Row.ValuesType = TypeDetails.AdjustValue(Undefined);
	EndDo;
	
	Return New ValueStorage(ValuesTypesOfAccessKindsAndRightsSettingsOwners);
	
EndFunction

// For internal use only.
Function MetadataObjectsRightsRestrictionsKinds() Export
	
	Return New Structure("UpdateDate, Table", '00010101');
	
EndFunction

#Region UniversalRestriction

Function BlankRefsOfGroupsAndValuesTypes() Export
	
	AccessKindsGroupsAndValuesTypes = AccessManagementInternalCached.AccessKindsGroupsAndValuesTypes();
	BlankRefs = New Map;
	
	For Each Row In AccessKindsGroupsAndValuesTypes Do
		BlankRefs.Insert(TypeOf(Row.GroupAndValueType), Row.GroupAndValueType);
	EndDo;
	
	Return New FixedMap(BlankRefs);
	
EndFunction

Function RestrictionParametersCache(CachedDataKey) Export
	
	Storage = New Structure;
	Storage.Insert("LeadingListsChecked", New Map);
	Storage.Insert("ListsRestrictions",       New Map);
	Storage.Insert("TransactionIDs", New Map);
	
	Return New FixedStructure(Storage);
	
EndFunction

Function ChangedListsCacheOnDisabledAccessKeysUpdate() Export
	
	Return SessionParameters.DIsableAccessKeysUpdate.EditedLists.Get();
	
EndFunction

Function ListsWithRestriction() Export
	
	Lists = New Map;
	SSLSubsystemsIntegration.OnFillListsWithAccessRestriction(Lists);
	AccessManagementOverridable.OnFillListsWithAccessRestriction(Lists);
	
	ListsProperties = New Map;
	For Each List In Lists Do
		FullName = List.Key.FullName();
		ListsProperties.Insert(FullName, List.Value);
	EndDo;
	
	Return New FixedMap(ListsProperties);
	
EndFunction

Function AllowedAccessKey() Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	Ref = Catalogs.AccessKeys.GetRef(
		New UUID("8bfeb2d1-08c3-11e8-bcf8-d017c2abb532"));
	
	RefInDatabase = Common.ObjectAttributeValue(Ref, "Ref");
	If Not ValueIsFilled(RefInDatabase) Then
		AllowedKey = Catalogs.AccessKeys.CreateItem();
		AllowedKey.SetNewObjectRef(Ref);
		AllowedKey.Description = NStr("ru = 'Разрешенный ключ доступа'; en = 'Allowed access key'; pl = 'Autoryzowany klucz dostępu';es_ES = 'Clave de acceso permitida';es_CO = 'Clave de acceso permitida';tr = 'Izin verilmiş erişim anahtarı';it = 'La chiave di accesso autorizzata';de = 'Erlaubter Zugriffsschlüssel'");
		
		Lock = New DataLock;
		LockItem = Lock.Add("Catalog.AccessKeys");
		LockItem.SetValue("Ref", Ref);
		
		BeginTransaction();
		Try
			Lock.Lock();
			RefInDatabase = Common.ObjectAttributeValue(Ref, "Ref");
			If Not ValueIsFilled(RefInDatabase) Then
				AllowedKey.Write();
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Return Ref;
	
EndFunction

Function AllowedBlankAccessGroupsSet() Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	Ref = Catalogs.AccessGroupsSets.GetRef(
		New UUID("b5bc5b29-a11d-11e8-8787-b06ebfbf08c7"));
	
	RefInDatabase = Common.ObjectAttributeValue(Ref, "Ref");
	If Not ValueIsFilled(RefInDatabase) Then
		AllowedBlankSet = Catalogs.AccessGroupsSets.CreateItem();
		AllowedBlankSet.SetNewObjectRef(Ref);
		AllowedBlankSet.Description = NStr("ru = 'Разрешенный пустой набор групп доступа'; en = 'Allowed blank access group set'; pl = 'Dozwolony pusty zestaw grup dostępu';es_ES = 'Conjunto de grupos de acceso permitido vacío';es_CO = 'Conjunto de grupos de acceso permitido vacío';tr = 'Erişim grupların izin verilen boş kümesi';it = 'Il gruppo di accesso permesso bianco è impostato';de = 'Erlaubtes leeres Set von Zugriffsgruppen'");
		AllowedBlankSet.SetItemsType = Catalogs.AccessGroups.EmptyRef();
		
		Lock = New DataLock;
		LockItem = Lock.Add("Catalog.AccessGroupsSets");
		LockItem.SetValue("Ref", Ref);
		
		BeginTransaction();
		Try
			Lock.Lock();
			RefInDatabase = Common.ObjectAttributeValue(Ref, "Ref");
			If Not ValueIsFilled(RefInDatabase) Then
				AllowedBlankSet.Write();
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Return Ref;
	
EndFunction

Function AccessKeyDimensions() Export
	
	KeyMetadata = Metadata.Catalogs.AccessKeys;
	
	If SimilarItemsInCollectionCount(KeyMetadata.Attributes, "Value") <> 5 Then
		Raise
			NStr("ru = 'В справочнике AccessKeys должно быть 5 реквизитов Значение* и не более.'; en = 'The AccessKeys catalog can contain maximum 5 Value* attributes.'; pl = 'W poradniku AccessKeys musi być 5 rekwizytów Wartość* i nie więcej.';es_ES = 'En el catálogo AccessKeys debe haber 5 requisitos Valor* y no más.';es_CO = 'En el catálogo AccessKeys debe haber 5 requisitos Valor* y no más.';tr = 'AccessKeys dizinde en fazla 5 adet Değer* özelliği olmalıdır.';it = 'Il catalogo AccessKeys può contenere massimo 5 attributi di Value*.';de = 'Das Verzeichnis ZugriffsSchlüssel sollte 5 Details zu Wert* enthalten und nicht mehr.'");
	EndIf;
	
	If KeyMetadata.TabularSections.Find("Header") = Undefined
	 Or SimilarItemsInCollectionCount(KeyMetadata.TabularSections.Header.Attributes, "Value", 6) <> 5 Then
		Raise
			NStr("ru = 'В справочнике AccessKeys должна быть табличная часть Header с 5 реквизитами Value* и не более.'; en = 'The AccessKeys catalog can contain the Header tabular section with maximum 5 Value* attribute.'; pl = 'W poradniku AccessKeys część tabelaryczna Nagłówek musi być z 5 niezbędnymi szczegółami Wartość* i nie więcej.';es_ES = 'En el catálogo AccessKeys debe haber sección tabular Header con 5 requisitos Value* y no más.';es_CO = 'En el catálogo AccessKeys debe haber sección tabular Header con 5 requisitos Value* y no más.';tr = 'AccessKeys dizinde en fazla 5 adet Değer* özelliğine sahip Başlık sekmeli bölüm olmalıdır.';it = 'Il catalogo AccessKeys può contenere la sezione tabellare Intestazione con massimo 5 attributi di Value*.';de = 'Das Verzeichnis ZugriffsSchlüssel sollte der tabellarische Teil der Überschrift mit 5 Details Wert* und nicht mehr vorhanden sein.'");
	EndIf;
	
	TabularSectionsCount = SimilarItemsInCollectionCount(KeyMetadata.TabularSections, "TabularSection");
	If TabularSectionsCount < 1 Or TabularSectionsCount > 12 Then
		Raise
			NStr("ru = 'В справочнике AccessKeys должно быть от 1 до 12 табличных частей TabularSection*.'; en = 'The AccessKeys catalog must contain from 1 to 12 TabularSection* tabular sections.'; pl = 'W poradniku AccessKeys musi być od 1 do 12 części tabelarycznych TabularSection*.';es_ES = 'En el catálogo AccessKeys debe haber de 1 a 12 secciones tabulares de TabularSection*.';es_CO = 'En el catálogo AccessKeys debe haber de 1 a 12 secciones tabulares de TabularSection*.';tr = 'AccessKeys dizinde 1 ile 12 TabularSection* sekmeliş bölüm olmalıdır.';it = 'Il catalogo AccessKeys deve contenere da 1 a 12 sezioni tabellari TabularSection*.';de = 'Das Verzeichnis ZugriffsSchlüssel sollte 1 bis 12 tabellarische Teile TabellarischerTeil* enthalten.'");
	EndIf;
	
	TabularSectionsCount = 0;
	TabularSectionAttributesCount = 0;
	For Each TabularSection In KeyMetadata.TabularSections Do
		If Not StrStartsWith(TabularSection.Name, "TabularSection") Then
			Continue;
		EndIf;
		TabularSectionsCount = TabularSectionsCount + 1;
		Count = SimilarItemsInCollectionCount(TabularSection.Attributes, "Value");
		If Count < 1 Or Count > 15 Then
			TabularSectionAttributesCount = 0;
			Break;
		EndIf;
		If TabularSectionAttributesCount <> 0
		   AND TabularSectionAttributesCount <> Count Then
			
			TabularSectionAttributesCount = 0;
			Break;
		EndIf;
		TabularSectionAttributesCount = Count;
	EndDo;
	
	If TabularSectionAttributesCount = 0 Then
		Raise
			NStr("ru = 'В справочнике AccessKeys в табличных частях TabularSection*
			           |допустимо только одинаковое количество реквизитов Value* и не более 15.'; 
			           |en = 'In the AccessKeys catalog in the TabularSection* tabular sections
			           |, only the same number of the Value* attributes is allowed, but not more than 15.'; 
			           |pl = 'W poradniku AccessKeys w częściach tabelarycznych TabularSection*
			           |dopuszcza się tylko taką samą ilość szczegółów Value* i nie więcej 15.';
			           |es_ES = 'En el catálogo AccessKeys en las secciones tabulares TabularSection*
			           |se admite solo la misma cantidad de requisitos Value* y no más de 15.';
			           |es_CO = 'En el catálogo AccessKeys en las secciones tabulares TabularSection*
			           |se admite solo la misma cantidad de requisitos Value* y no más de 15.';
			           |tr = 'TabularSection* sekmeli bölümlerinde AccessKeys dizinde 
			           | yalnızca en fazla 15 adet aynı Value* özellikleri bulunabilir.';
			           |it = 'Nel catalogo AccessKeys nelle sezioni tabellari TabularSection*
			           | solo lo stesso numero degli attributi Value* è permesso, ma non più di 15.';
			           |de = 'Im Verzeichnis ZugriffsSchlüssel in den tabellarischen Teilen TabellarischerTeil*
			           |ist nur die gleiche Anzahl von Attributen erlaubt und nicht mehr als 15.'");
	EndIf;
	
	Dimensions = New Structure;
	Dimensions.Insert("TabularSectionsCount",          TabularSectionsCount);
	Dimensions.Insert("TabularSectionAttributesCount", TabularSectionAttributesCount);
	
	Return New FixedStructure(Dimensions);
	
EndFunction

Function BasicRegisterFieldsCount(RegisterName = "") Export
	
	If RegisterName = "" Then
		KeysRegisterMetadata = Metadata.InformationRegisters.AccessKeysForRegisters;
	Else
		KeysRegisterMetadata = Metadata.InformationRegisters[RegisterName];
	EndIf;
	
	LastFieldNumber = 0;
	For Each Dimension In KeysRegisterMetadata.Dimensions Do
		If Dimension.Name = "Register" Then
			If RegisterName = "" Then
				Continue;
			EndIf;
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'В отдельном регистре сведений %1
				           |не должно быть измерения %2.'; 
				           |en = 'There must not be dimension %2
				           |in a separate %1 information register.'; 
				           |pl = 'W oddzielnym rejestrze informacji %1
				           | nie powinno być pomiaru %2.';
				           |es_ES = 'En el registro separado de información %1
				           |no debe haber dimensiones %2.';
				           |es_CO = 'En el registro separado de información %1
				           |no debe haber dimensiones %2.';
				           |tr = 'Ayrı bir veri kayıt cihazında %1
				           | ölçüm olmamalıdır %2.';
				           |it = 'Non devono esserci dimensioni %2
				           |in un registro%1 informazioni separato.';
				           |de = 'Es sollte keine Messung %2 in einem separaten Register %1
				           |erfolgen.'"), RegisterName, "Register");
		EndIf;
		If Dimension.Name = "ForExternalUsers" Then
			Continue;
		EndIf;
		If StrLen(Dimension.Name) <> StrLen( "Field" ) + 1 Or Not StrStartsWith(Dimension.Name, "Field") Then // PATCHED:
			Break;
		EndIf;
		If Right(Dimension.Name, 1) <> String(LastFieldNumber + 1) Then
			Break;
		EndIf;
		LastFieldNumber = LastFieldNumber + 1;
	EndDo;
	
	Return LastFieldNumber;
	
EndFunction

Function MaxBasicRegisterFieldsCount() Export
	
	// When changing, synchronously change the access restriction template ForRegister.
	Return Number(5);
	
EndFunction

Function BlankBasicFieldsValues(Count) Export
	
	BlankValues = New Structure;
	For Number = 1 To Count Do
		BlankValues.Insert("Field" + Number, Enums.AdditionalAccessValues.Null);
	EndDo;
	
	Return BlankValues;
	
EndFunction

Function LanguageSyntax() Export
	
	Return AccessManagementInternal.LanguageSyntax();
	
EndFunction

Function NodesToCheckAvailability(List, IsExceptionsList) Export
	
	Return AccessManagementInternal.NodesToCheckAvailability(List, IsExceptionsList);
	
EndFunction

Function SeparatedDataUnavailable() Export
	
	Return Not Common.SeparatedDataUsageAvailable();
	
EndFunction

Function PredefinedMetadataObjectIDDetails(FullMetadataObjectName) Export
	
	Names = AccessManagementInternalCached.PredefinedCatalogItemsNames(
		"MetadataObjectIDs");
	
	Name = StrReplace(FullMetadataObjectName, ".", "");
	
	If Names.Find(Name) <> Undefined Then
		Return "MetadataObjectIDs." + Name;
	EndIf;
	
	Names = AccessManagementInternalCached.PredefinedCatalogItemsNames(
		"ExtensionObjectIDs");
	
	If Names.Find(Name) <> Undefined Then
		Return "ExtensionObjectIDs." + Name;
	EndIf;
	
	MetadataObject = Metadata.FindByFullName(FullMetadataObjectName);
	If MetadataObject = Undefined Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось получить имя предопределенного идентификатора объекта метаданных
			           |так как не существует указанный объект метаданных:
			           |""%1"".'; 
			           |en = 'Cannot get a name of predefined metadata object ID
			           |as the specified metadata object does not exist:
			           |""%1"".'; 
			           |pl = 'Nie udało się uzyskać nazwę predefiniowanego identyfikatora obiektu metadanych
			           |tak jak nie istnieje podany obiekt metadanych:
			           |""%1"".';
			           |es_ES = 'No se ha podido recibir el nombre del identificador predeterminado del objeto de metadatos
			           |porque el objeto de metadatos indicado no existe:
			           |""%1"".';
			           |es_CO = 'No se ha podido recibir el nombre del identificador predeterminado del objeto de metadatos
			           |porque el objeto de metadatos indicado no existe:
			           |""%1"".';
			           |tr = 'Belirtilen metaveri nesnesi bulunmadığından dolayı önceden tanımlanmış
			           |metaveri tanımlayıcısının adı elde edilemedi: 
			           |""%1"".';
			           |it = 'Non è stato possibile ricevere il nome dell''identificatore prestabilito dell''oggetto di metadati
			           |poiché non esiste l''oggetto di metadati specificato:
			           |""%1"".';
			           |de = 'Es war nicht möglich, den Namen des vordefinierten Identifikators des Metadatenobjekts zu erhalten,
			           |da es kein angegebenes Metadatenobjekt gibt:
			           |""%1"".'"),
			FullMetadataObjectName);
		Raise ErrorText;
	EndIf;
	
	If MetadataObject.ConfigurationExtension() = Undefined Then
		Return "MetadataObjectIDs." + Name;
	EndIf;
	
	Return "ExtensionObjectIDs." + Name;
	
EndFunction

Function PredefinedCatalogItemsNames(CatalogName) Export
	
	Return Metadata.Catalogs[CatalogName].GetPredefinedNames();
	
EndFunction

Function AllowedAccessKeysValuesTypes() Export
	
	KeyDimensions = AccessKeyDimensions();
	CatalogAttributes      = Metadata.Catalogs.AccessKeys.Attributes;
	CatalogTabularSections = Metadata.Catalogs.AccessKeys.TabularSections;
	
	AllowedTypes = CatalogAttributes.Value1.Type.Types();
	For AttributeNumber = 2 To 5 Do
		ClarifyAllowedTypes(AllowedTypes, CatalogAttributes["Value" + AttributeNumber]);
	EndDo;
	For AttributeNumber = 6 To 10 Do
		ClarifyAllowedTypes(AllowedTypes, CatalogTabularSections.Header.Attributes["Value" + AttributeNumber]);
	EndDo;
	For TabularSectionNumber = 1 To KeyDimensions.TabularSectionsCount Do
		TabularSection = CatalogTabularSections["TabularSection" + TabularSectionNumber];
		For AttributeNumber = 1 To KeyDimensions.TabularSectionAttributesCount Do
			ClarifyAllowedTypes(AllowedTypes, TabularSection.Attributes["Value" + AttributeNumber]);
		EndDo;
	EndDo;
	
	Return New TypeDescription(AllowedTypes);
	
EndFunction

Function LastCheckOfAllowedSetsVersion() Export
	
	Return New Structure("Date", '00010101');
	
EndFunction

Function RolesNamesBasicRights(ForExternalUsers) Export
	
	RolesNames = New Array;
	
	For Each Role In Metadata.Roles Do
		RoleName = Role.Name;
		If Not StrStartsWith(Upper(RoleName), Upper("BasicRights")) Then
			Continue;
		EndIf;
		RoleForExternalUsers = StrStartsWith(Upper(RoleName), Upper("ExternalUsersBasicRights"));
		If RoleForExternalUsers = ForExternalUsers Then 
			RolesNames.Add(RoleName);
		EndIf;
	EndDo;
	
	Return RolesNames;
	
EndFunction

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Function AccessKindsValuesTypes()
	
	AccessKindsProperties = AccessManagementInternalCached.AccessKindsProperties();
	
	AccessKindsValuesTypes = New ValueTable;
	AccessKindsValuesTypes.Columns.Add("AccessKind",  Metadata.DefinedTypes.AccessValue.Type);
	AccessKindsValuesTypes.Columns.Add("ValuesType", Metadata.DefinedTypes.AccessValue.Type);
	
	For each KeyAndValue In AccessKindsProperties.ByValuesTypes Do
		Row = AccessKindsValuesTypes.Add();
		Row.AccessKind = KeyAndValue.Value.Ref;
		
		Types = New Array;
		Types.Add(KeyAndValue.Key);
		TypeDetails = New TypeDescription(Types);
		
		Row.ValuesType = TypeDetails.AdjustValue(Undefined);
	EndDo;
	
	Return AccessKindsValuesTypes;
	
EndFunction

#Region UniversalRestriction

Function SimilarItemsInCollectionCount(Collection, NameBeginning, InitialNumber = 1)
	
	SimilarItemsCount = 0;
	MaxNumber = 0;
	
	For Each CollectionItem In Collection Do
		If Not StrStartsWith(CollectionItem.Name, NameBeginning) Then
			Continue;
		EndIf;
		ItemNumber = Mid(CollectionItem.Name, StrLen(NameBeginning) + 1);
		If StrLen(ItemNumber) < 1 Or StrLen(ItemNumber) > 2 Then
			SimilarItemsCount = 0;
			Break;
		EndIf;
		If Not ( Left(ItemNumber, 1) >= "0" AND Left(ItemNumber, 1) <= "9" ) Then
			SimilarItemsCount = 0;
			Break;
		EndIf;
		If StrLen(ItemNumber) = 2
		   AND Not ( Left(ItemNumber, 2) >= "0" AND Left(ItemNumber, 2) <= "9" ) Then
			SimilarItemsCount = 0;
			Break;
		EndIf;
		ItemNumber = Number(ItemNumber);
		If ItemNumber < InitialNumber Then
			SimilarItemsCount = 0;
			Break;
		EndIf;
		
		SimilarItemsCount = SimilarItemsCount + 1;
		MaxNumber = ?(MaxNumber > ItemNumber, MaxNumber, ItemNumber);
	EndDo;
	
	If MaxNumber - InitialNumber + 1 <> SimilarItemsCount Then
		SimilarItemsCount = 0;
	EndIf;
	
	Return SimilarItemsCount;
	
EndFunction

// For the AllowedAccessKeysValuesTypes function.
Procedure ClarifyAllowedTypes(AllowedTypes, Attribute);
	
	Index = AllowedTypes.Count() - 1;
	TypesDetails = Attribute.Type;
	
	While Index >= 0 Do
		If Not TypesDetails.ContainsType(AllowedTypes[Index]) Then
			AllowedTypes.Delete(Index);
		EndIf;
		Index = Index - 1;
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion
