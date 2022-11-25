#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Updates user groups to check allowed values for the Users and ExternalUsers access kinds.
// 
// 
// It must be called:
// 1) When adding a new user (or an external user),
//    When adding a new user group (or an external user group), when changing the user group members 
//    (or groups of external users).
//    Parameters = Structure with one of the properties or both of them:
//    - Users:        a single user or an array.
//    - UserGroups: a single user group or an array.
//
// 2) When changing assignee groups.
//    Parameters = Structure with one property:
//    - PerformersGroups: Undefined, a single assignee group or an array.
//
// 3) When changing an authorization object of an external user.
//    Parameters = Structure with one property:
//    - AuthorizationObjects: Undefined, a single authorization object or an array.
//
// Types used in the parameters:
//
//  User         - CatalogRef.Users,
//                         CatalogRef.ExternalUsers.
//
//  User group - CatalogRef.UserGroups,
//                         CatalogRef.ExternalUserGroups.
//
//  Performer - CatalogRef.Users,
//                         CatalogRef.ExternalUsers.
// 
//  Group of assignees - for example, CatalogRef.TasksPerformersGroups.
//
//  Authorization object - for example, CatalogRef.Individuals.
//
// Parameters:
//  Parameters     - Undefined - update all without filter.
//                  Structure - see options above.
//
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure UpdateUsersGroupings(Parameters = Undefined, HasChanges = Undefined) Export
	
	UpdateKind = "";
	
	If Parameters = Undefined Then
		UpdateKind = "All";
	
	ElsIf Parameters.Count() = 2
	        AND Parameters.Property("Users")
	        AND Parameters.Property("UserGroups") Then
		
		UpdateKind = "UsersAndUserGroups";
		
	ElsIf Parameters.Count() = 1
	        AND Parameters.Property("Users") Then
		
		UpdateKind = "UsersAndUserGroups";
		
	ElsIf Parameters.Count() = 1
	        AND Parameters.Property("UserGroups") Then
		
		UpdateKind = "UsersAndUserGroups";
		
	ElsIf Parameters.Count() = 1
	        AND Parameters.Property("PerformersGroups") Then
		
		UpdateKind = "PerformersGroups";
		
	ElsIf Parameters.Count() = 1
	        AND Parameters.Property("AuthorizationObjects") Then
		
		UpdateKind = "AuthorizationObjects";
	Else
		Raise
			NStr("ru = 'Ошибка в процедуре UpdateUsersGroupings
			           |модуля менеджера регистра сведений Группы значений доступа.
			           |
			           |Указаны неверные параметры.'; 
			           |en = 'An error occurred in the UpdateUsersGroupings 
			           |procedure of manager module of the Access value group information register.
			           |
			           |Parameters are incorrect.'; 
			           |pl = 'Błąd w procedurze UpdateUsersGroupings
			           |modułu menedżera rejestru informacji Grupy wartości dostępu.
			           |
			           |Parametry są błędn.';
			           |es_ES = 'Error en el procedimiento UpdateUsersGroupings
			           |del módulo de gestor del registro de información de Grupos de valores de acceso.
			           |
			           |Se han indicado parámetros incorrectos.';
			           |es_CO = 'Error en el procedimiento UpdateUsersGroupings
			           |del módulo de gestor del registro de información de Grupos de valores de acceso.
			           |
			           |Se han indicado parámetros incorrectos.';
			           |tr = 'Bilgi kayıt yöneticisi modülü Erişim değeri gruplarının 
			           |KullanıcıGruplarınıYenile prosedüründe bir hata oluştu. 
			           |
			           |Yanlış parametreler belirtildi.';
			           |it = 'Errore nella procedura UpdateUsersGroupings
			           |del modulo manager del registro di informazioni sul gruppo di valori di accesso.
			           |
			           |Parametri non corretti.';
			           |de = 'Fehler in der Prozedur UpdateUsersGroupings
			           |des Informationsregistermanagers der Zugriffswertgruppen.
			           |
			           |Ungültige Parameter angegeben.'");
	EndIf;
	
	BeginTransaction();
	Try
		If InfobaseUpdate.InfobaseUpdateInProgress()
		 Or InfobaseUpdate.IsCallFromUpdateHandler() Then
			
			DeleteUnusedRecords(HasChanges);
		EndIf;
		
		If UpdateKind = "UsersAndUserGroups" Then
			
			If Parameters.Property("Users") Then
				UpdateUsers(        Parameters.Users, HasChanges);
				UpdatePerformersGroups( , Parameters.Users, HasChanges);
			EndIf;
			
			If Parameters.Property("UserGroups") Then
				UpdateUserGroups(Parameters.UserGroups, HasChanges);
			EndIf;
			
		ElsIf UpdateKind = "PerformersGroups" Then
			UpdatePerformersGroups(Parameters.PerformersGroups, , HasChanges);
			
		ElsIf UpdateKind = "AuthorizationObjects" Then
			UpdateAuthorizationObjects(Parameters.AuthorizationObjects, HasChanges);
		Else
			UpdateUsers(       ,   HasChanges);
			UpdateUserGroups( ,   HasChanges);
			UpdatePerformersGroups(  , , HasChanges);
			UpdateAuthorizationObjects(  ,   HasChanges);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Removes unused data after changing content of value types and access value groups.
// 
//
Procedure UpdateAuxiliaryRegisterDataByConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		"StandardSubsystems.AccessManagement.GroupAndAccessValueTypes");
	
	If LastChanges = Undefined
	 OR LastChanges.Count() > 0 Then
		
		If Constants.LimitAccessAtRecordLevel.Get() Then
			AccessManagementInternal.SetDataFillingForAccessRestriction(True);
		EndIf;
		UpdateEmptyAccessValueGroups();
		DeleteUnusedRecords();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Updates register data after changing access values.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	DeleteUnusedRecords(HasChanges);
	
	UpdateUsersGroupings( , HasChanges);
	
	UpdateAccessValuesGroups( , HasChanges);
	
EndProcedure

// Updates access value groups in the InformationRegister.AccessValuesGroups.
//
// Parameters:
//  AccessValues - CatalogObject,
//                  - CatalogRef.
//                  - Array of values of the types specified above.
//                  - Undefined - without filter.
//                    Value type must be included in the Value dimension types of the 
//                    AccessValuesGroups information register.
//                    If Object is passed, the update is performed only when it is changed.
//
//  HasChanges   - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                    
//
Procedure UpdateAccessValuesGroups(AccessValues = Undefined,
                                        HasChanges   = Undefined) Export
	
	ValuesTypesWithChanges = New Map;
	
	If AccessValues = Undefined Then
		
		AccessKindsProperties = AccessManagementInternalCached.AccessKindsProperties();
		AccessValuesWithGroups = AccessKindsProperties.AccessValuesWithGroups;
		
		Query = New Query;
		QueryText =
		"SELECT
		|	CurrentTable.Ref
		|FROM
		|	&CurrentTable AS CurrentTable";
		
		For Each TableName In AccessValuesWithGroups.NamesOfTablesToUpdate Do
			
			Query.Text = StrReplace(QueryText, "&CurrentTable", TableName);
			Selection = Query.Execute().Select();
			
			ObjectManager = Common.ObjectManagerByFullName(TableName);
			UpdateAccessValueGroups(ObjectManager.EmptyRef(), HasChanges, ValuesTypesWithChanges);
			
			While Selection.Next() Do
				UpdateAccessValueGroups(Selection.Ref, HasChanges, ValuesTypesWithChanges);
			EndDo;
		EndDo;
		
	ElsIf TypeOf(AccessValues) = Type("Array") Then
		
		For each AccessValue In AccessValues Do
			UpdateAccessValueGroups(AccessValue, HasChanges, ValuesTypesWithChanges);
		EndDo;
	Else
		UpdateAccessValueGroups(AccessValues, HasChanges, ValuesTypesWithChanges);
	EndIf;
	
	AccessManagementInternal.ScheduleUpdateOfDependentListsByValuesWithGroups(
		ValuesTypesWithChanges);
	
EndProcedure

// Fills groups for blank references to the access value types in use.
Procedure UpdateEmptyAccessValueGroups() Export
	
	AccessKindsProperties = AccessManagementInternalCached.AccessKindsProperties();
	AccessValuesWithGroups = AccessKindsProperties.AccessValuesWithGroups;
	
	ValuesTypesWithChanges = New Map;
	
	For Each TableName In AccessValuesWithGroups.NamesOfTablesToUpdate Do
		BlankRef = PredefinedValue(TableName + ".EmptyRef");
		UpdateAccessValueGroups(BlankRef, Undefined, ValuesTypesWithChanges);
	EndDo;
	
	AccessManagementInternal.ScheduleUpdateOfDependentListsByValuesWithGroups(
		ValuesTypesWithChanges);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	// Data registration is not required.
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	UpdateRegisterData();
	
	Parameters.ProcessingCompleted = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Deletes unnecessary records if any are found.
Procedure DeleteUnusedRecords(HasChanges = Undefined)
	
	AccessKindsProperties = AccessManagementInternalCached.AccessKindsProperties();
	ValuesGroupsTypes = AccessKindsProperties.AccessValuesWithGroups.ValueGroupTypesForUpdate;
	
	GroupsAndValuesTypesTable = New ValueTable;
	GroupsAndValuesTypesTable.Columns.Add("ValuesType",      Metadata.DefinedTypes.AccessValue.Type);
	GroupsAndValuesTypesTable.Columns.Add("ValuesGroupsType", Metadata.DefinedTypes.AccessValue.Type);
	
	For each KeyAndValue In ValuesGroupsTypes Do
		If TypeOf(KeyAndValue.Key) = Type("Type") Then
			Continue;
		EndIf;
		Row = GroupsAndValuesTypesTable.Add();
		Row.ValuesType      = KeyAndValue.Key;
		Row.ValuesGroupsType = KeyAndValue.Value;
	EndDo;
	
	// Data groups in the register.
	// 0 - Standard access values.
	// 1 - Common or external users.
	// 2 - Groups of common or external users.
	// 3 - Assignee groups.
	// 4 - Authorization objects.
	
	
	Query = New Query;
	Query.SetParameter("GroupsAndValuesTypesTable", GroupsAndValuesTypesTable);
	Query.Text =
	"SELECT
	|	TableTypes.ValuesType AS ValuesType,
	|	TableTypes.ValuesGroupsType AS ValuesGroupsType
	|INTO GroupsAndValuesTypesTable
	|FROM
	|	&GroupsAndValuesTypesTable AS TableTypes
	|
	|INDEX BY
	|	TableTypes.ValuesType,
	|	TableTypes.ValuesGroupsType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ValueGroups.AccessValue AS AccessValue,
	|	ValueGroups.AccessValuesGroup AS AccessValuesGroup,
	|	ValueGroups.DataGroup AS DataGroup
	|FROM
	|	(SELECT
	|		AccessValuesGroups.AccessValue AS AccessValue,
	|		AccessValuesGroups.AccessValuesGroup AS AccessValuesGroup,
	|		AccessValuesGroups.DataGroup AS DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.AccessValue = UNDEFINED
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 0
	|		AND NOT TRUE IN
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						GroupsAndValuesTypesTable AS GroupsAndValuesTypesTable
	|					WHERE
	|						VALUETYPE(GroupsAndValuesTypesTable.ValuesType) = VALUETYPE(AccessValuesGroups.AccessValue)
	|						AND VALUETYPE(GroupsAndValuesTypesTable.ValuesGroupsType) = VALUETYPE(AccessValuesGroups.AccessValuesGroup))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 1
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) <> TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) <> TYPE(Catalog.ExternalUsers)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 1
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.UserGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 1
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 2
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) <> TYPE(Catalog.UserGroups)
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 2
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.UserGroups)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.UserGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 2
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsersGroups)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 3
	|		AND (VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.Users)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.UserGroups)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsers)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsersGroups))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 3
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.UserGroups)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 4
	|		AND (VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.Users)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.UserGroups)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsers)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsersGroups))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 4
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup > 4) AS ValueGroups";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
		Selection = QueryResult.Select();
		While Selection.Next() Do
			RecordSet = CreateRecordSet();
			RecordSet.Filter.AccessValue.Set(Selection.AccessValue);
			RecordSet.Filter.AccessValuesGroup.Set(Selection.AccessValuesGroup);
			RecordSet.Filter.DataGroup.Set(Selection.DataGroup);
			RecordSet.Write();
			HasChanges = True;
		EndDo;
	EndIf;
	
EndProcedure

// Updates access value groups in InformationRegister.AccessValuesGroups.
//
// Parameters:
//  AccessValue - CatalogRef.
//                    CatalogObject.
//                    If Object is passed, the update is performed only when it is changed.
//
//  HasChanges   - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                    
//
Procedure UpdateAccessValueGroups(AccessValue, HasChanges, ValuesTypesWithChanges)
	
	SetPrivilegedMode(True);
	
	AccessValueType = TypeOf(AccessValue);
	
	AccessKindsProperties = AccessManagementInternalCached.AccessKindsProperties();
	AccessValuesWithGroups = AccessKindsProperties.AccessValuesWithGroups;
	
	AccessKindProperties = AccessValuesWithGroups.ByTypesForUpdate.Get(AccessValueType);
	
	ErrorTitle =
		NStr("ru = 'Ошибка при обновлении групп значений доступа.'; en = 'An error occurred when updating access value groups.'; pl = 'Błąd podczas aktualizowania grup wartości dostępu.';es_ES = 'Error al actualizar los grupos de valores de acceso.';es_CO = 'Error al actualizar los grupos de valores de acceso.';tr = 'Erişim değeri grupları güncellenirken bir hata oluştu.';it = 'Errore durante l''aggiornamento dei gruppi di valori di accesso.';de = 'Fehler beim Aktualisieren der Zugriffswertgruppen.'")
		+ Chars.LF
		+ Chars.LF;
	
	If AccessKindProperties = Undefined Then
		Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Для типа ""%1""
			           |не настроено использование групп значений доступа.'; 
			           |en = 'For type ""%1""
			           |usage of access value groups is not configured.'; 
			           |pl = 'Dla typu ""%1""
			           |nie jest skonfigurowano wykorzystanie grup wartości dostępu.';
			           |es_ES = 'Para el tipo ""%1""
			           |no se ha ajustado el uso de los grupos de valores de acceso.';
			           |es_CO = 'Para el tipo ""%1""
			           |no se ha ajustado el uso de los grupos de valores de acceso.';
			           |tr = 'Erişim değeri grupları %1 kullanımı 
			           |"" türü için ayarlanmamış.';
			           |it = 'Per il tipo ""%1""
			           |l''uso dei gruppi di valore di accesso non è configurato.';
			           |de = 'Für den Typ ""%1""
			           |sind keine Gruppen von Zugriffswerten konfiguriert.'"),
			String(AccessValueType));
	EndIf;
	
	If AccessValuesWithGroups.ByRefTypesForUpdate.Get(AccessValueType) = Undefined Then
		Ref = UsersInternal.ObjectRef(AccessValue);
		Object = AccessValue;
	Else
		Ref = AccessValue;
		Object = Undefined;
	EndIf;
	
	// Preparing previous field values.
	AttributeName      = "AccessGroup";
	TabularSectionName = "AccessGroups";
	
	If AccessKindProperties.ValuesGroupsType = Type("Undefined") Then
		FieldForQuery = "Ref";
	ElsIf AccessKindProperties.MultipleValuesGroups Then
		FieldForQuery = TabularSectionName;
	Else
		FieldForQuery = AttributeName;
	EndIf;
	
	Try
		PreviousValues = Common.ObjectAttributesValues(Ref, FieldForQuery);
	Except
		Error = ErrorInfo();
		TypeMetadata = Metadata.FindByType(AccessValueType);
		
		If AccessKindProperties.ValuesGroupsType = Type("Undefined") Then
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'У значения доступа ""%1""
				           |типа ""%2""
				           |не удалось прочитать реквизит Ссылка по причине:
				           |%3'; 
				           |en = 'Cannot read the Ref attribute of access value ""%1""
				           |of type ""%2""
				           | due to:
				           |%3'; 
				           |pl = 'Wartość dostępu ""%1"" 
				           |typu ""%2"" 
				           |nie powiódł się odczyt wymaganych danych Odnośnik do powodu:
				           |%3';
				           |es_ES = 'No se ha podido leer el requisito Enlace para el valor de acceso ""%1""
				           |del tipo ""%2""
				           | a causa de:
				           |%3';
				           |es_CO = 'No se ha podido leer el requisito Enlace para el valor de acceso ""%1""
				           |del tipo ""%2""
				           | a causa de:
				           |%3';
				           |tr = '""%1""
				           | tür %2""
				           | erişim değeri aşağıdaki nedenle Referans özelliğini okuyamadı: 
				           |%3';
				           |it = 'Impossibile leggere il requisito Collegamento del valore di accesso ""%1""
				           |del tipo ""%2""
				           | a causa di:
				           |%3';
				           |de = 'Der Zugriffswert ""%1""
				           |vom Typ ""%2""
				           |konnte das Attribut Link aus folgendem Grund nicht lesen:
				           |%3'"),
				String(AccessValue),
				String(AccessValueType),
				BriefErrorDescription(Error));
			
		ElsIf AccessKindProperties.MultipleValuesGroups Then
			TabularSectionMetadata = TypeMetadata.TabularSections.Find("AccessGroups");
			
			If TabularSectionMetadata = Undefined
			 OR TabularSectionMetadata.Attributes.Find("AccessGroup") = Undefined Then
				
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'У типа значений доступа ""%1""
					           |не создана специальная табличная часть AccessGroups
					           |со специальным реквизитом AccessGroup.'; 
					           |en = 'Special tabular section AccessGroups
					           |with special attribute AccessGroup is not created
					           |for access value type ""%1"".'; 
					           |pl = 'Dla rodzaju wartości ""%1"" nie utworzono specjalnej 
					           |sekcji tabelarycznej AccessGroups ze specjalnym 
					           |atrybutem AccessGroup.';
					           |es_ES = 'La sección
					           |de la tabular especial AccessGroups con al atributo
					           |especial AccessGroup no se ha creado en el tipo de valores de acceso.""%1""';
					           |es_CO = 'La sección
					           |de la tabular especial AccessGroups con al atributo
					           |especial AccessGroup no se ha creado en el tipo de valores de acceso.""%1""';
					           |tr = 'AccessGroup özel tablo 
					           |sekmesi, AccessGroup özel niteliği ile 
					           |erişim değerleri türünde oluşturulmaz. ""%1""';
					           |it = 'La sezione tabellare speciale AccessGroups
					           |con il requisito speciale AccessGroup non è stata creata
					           |per il tipo di valore di accesso ""%1"".';
					           |de = 'Der Tabellen
					           |abschnitt Zugriffsgruppen mit dem speziellen
					           |Attribut Zugriffsgruppe wird nicht im Zugriffswertetyp erstellt. ""%1""'"),
					String(AccessValueType));
			Else
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'У значения доступа ""%1""
					           |типа ""%2""
					           |не удалось прочитать табличную часть AccessGroup
					           |с реквизитом AccessGroupпо причине:
					           |%3'; 
					           |en = 'Cannot read the AccessGroup tabular section
					           |with the AccessGroup attribute of access value ""%1""
					           |of type ""%2""
					           | due to:
					           |%3'; 
					           |pl = 'Nie udało się odczytać AccessGroup tabelarycznej sekcji
					           | wartości dostępu atrybutu AccessGroup ""%1""
					           |typu ""%2""
					           | z powodu:
					           |%3';
					           |es_ES = 'No se ha podido leer la sección tabular AccessGroup
					           |del valor de acceso ""%1""
					           |del tipo ""%2""
					           |con el requisito AccessGroup a causa de:
					           |%3';
					           |es_CO = 'No se ha podido leer la sección tabular AccessGroup
					           |del valor de acceso ""%1""
					           |del tipo ""%2""
					           |con el requisito AccessGroup a causa de:
					           |%3';
					           |tr = '""%1""
					           | tür %2""
					           | erişim değeri aşağıdaki nedenle ErişimGrubu özelliğine sahip ErişimGrubun 
					           |sekmeli bölümünü okuyamadı: 
					           |%3';
					           |it = 'Impossibile legger la sezione tabellare AccessGroup
					           |con il requisito AccessGroup del valore di accesso ""%1""
					           |del tipo ""%2""
					           | a causa di:
					           |%3';
					           |de = 'Der Zugriffswert ""%1""
					           |vom Typ ""%2""
					           |konnte den Tabellenteil der ZugriffsGruppe
					           |mit dem Attribut ZugriffsGruppe aus dem Grund nicht lesen:
					           |%3'"),
					String(AccessValue),
					String(AccessValueType),
					BriefErrorDescription(Error));
			EndIf;
		Else
			If TypeMetadata.Attributes.Find("AccessGroup") = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'У типа значений доступа ""%1""
					           |не создан специальный реквизит AccessGroup.'; 
					           |en = 'Special attribute AccessGroup 
					           |is not created for access value type ""%1"".'; 
					           |pl = 'Specjalny atrybut AccessGroup 
					           |nie został utworzony dla typu wartości dostępu""%1"".';
					           |es_ES = 'No se ha creado un requisito especial AccessGroup del tipo de valores de acceso ""%1""
					           |.';
					           |es_CO = 'No se ha creado un requisito especial AccessGroup del tipo de valores de acceso ""%1""
					           |.';
					           |tr = 'ErişimGrubu özel öznitelik 
					           |, ""%1""  tip erişim değerlerinde oluşturulmadı.';
					           |it = 'Il requisito speciale AccessGroup
					           |non è stato creato per il valore di accesso del tipo ""%1"".';
					           |de = 'Für die Zugriffswertetyp ""%1""
					           |wird kein spezielles Attribut für die ZugriffsGruppe erstellt.'"),
					String(AccessValueType));
			Else
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'У значения доступа ""%1""
					           |типа ""%2""
					           |не удалось прочитать реквизит AccessGroup по причине:
					           |%3'; 
					           |en = 'Cannot read the AccessGroup attribute of access value ""%1""
					           |of type ""%2""
					           | due to:
					           |%3'; 
					           |pl = 'Nie udało się odczytać AccessGroup atrybutu wartości dostępu""%1""
					           |typu ""%2""
					           | z powodu:
					           |%3';
					           |es_ES = 'No se ha podido leer un requisito AccessGroup para el valor de acceso ""%1""
					           |del tipo ""%2""
					           | a causa de:
					           |%3';
					           |es_CO = 'No se ha podido leer un requisito AccessGroup para el valor de acceso ""%1""
					           |del tipo ""%2""
					           | a causa de:
					           |%3';
					           |tr = '""%1""
					           | tür %2""
					           | erişim değeri aşağıdaki nedenle ErişimGrubu özelliğini okuyamadı: 
					           |%3';
					           |it = 'Impossibile leggere il requisito AccessGroup del valore di accesso ""%1""
					           |del tipo ""%2""
					           | a causa di:
					           |%3';
					           |de = 'Der Zugriffswert ""%1""
					           |des Typs ""%2""
					           |konnte das Attribut ZugriffsGruppe aus dem Grund nicht lesen:
					           |%3'"),
					String(AccessValue),
					String(AccessValueType),
					BriefErrorDescription(Error));
			EndIf;
		EndIf;
	EndTry;
	
	// Checking the object for changes.
	UpdateRequired = False;
	If Object <> Undefined Then
		
		If Object.IsNew() Then
			UpdateRequired = True;
			
		ElsIf AccessKindProperties.ValuesGroupsType <> Type("Undefined") Then
			
			If AccessKindProperties.MultipleValuesGroups Then
				Value = Object[TabularSectionName].Unload();
				Value.Sort(AttributeName);
				If PreviousValues[TabularSectionName] <> Undefined Then
					PreviousValues[TabularSectionName] = PreviousValues[TabularSectionName].Unload();
					PreviousValues[TabularSectionName].Sort(AttributeName);
				EndIf;
			Else
				Value = Object[AttributeName];
			EndIf;
			
			If NOT Common.DataMatch(Value, PreviousValues[FieldForQuery]) Then
				UpdateRequired = True;
			EndIf;
		EndIf;
		NewValues = Object;
	Else
		UpdateRequired = True;
		NewValues = PreviousValues;
	EndIf;
	
	If Not UpdateRequired Then
		Return;
	EndIf;
	
	If AccessKindProperties.ValuesGroupsType <> Type("Undefined")
	   AND (Object = Undefined Or Not Object.IsNew()) Then
		
		ValuesTypesWithChanges.Insert(AccessValueType, True);
	EndIf;
	
	// Preparing new records for update.
	NewRecords = CreateRecordSet().Unload();
	
	If AccessManagement.LimitAccessAtRecordLevel() Then
		
		// Adding value groups.
		If AccessKindProperties.ValuesGroupsType = Type("Undefined") Then
			Record = NewRecords.Add();
			Record.AccessValue       = Ref;
			Record.AccessValuesGroup = Ref;
		Else
			AccessKindsProperties = AccessManagementInternalCached.AccessKindsProperties();
			ValuesGroupsTypes = AccessKindsProperties.AccessValuesWithGroups.ValueGroupTypesForUpdate;
			
			AccessValuesGroupsEmptyRef = ValuesGroupsTypes.Get(TypeOf(Ref));
			
			If AccessKindProperties.MultipleValuesGroups Then
				If NewValues[TabularSectionName] = Undefined Then
					AccessValuesGroups = New ValueTable;
					AccessValuesGroups.Columns.Add("AccessGroup");
				Else
					AccessValuesGroups = NewValues[TabularSectionName].Unload();
				EndIf;
				If AccessValuesGroups.Count() = 0 Then
					AccessValuesGroups.Add();
				Else
					AccessValuesGroups.GroupBy("AccessGroup");
				EndIf;
				For each Row In AccessValuesGroups Do
					Record = NewRecords.Add();
					Record.AccessValue       = Ref;
					Record.AccessValuesGroup = Row[AttributeName];
					If TypeOf(Record.AccessValuesGroup) <> TypeOf(AccessValuesGroupsEmptyRef) Then
						Record.AccessValuesGroup = AccessValuesGroupsEmptyRef;
					EndIf;
				EndDo;
			Else
				Record = NewRecords.Add();
				Record.AccessValue       = Ref;
				Record.AccessValuesGroup = NewValues[AttributeName];
				If TypeOf(Record.AccessValuesGroup) <> TypeOf(AccessValuesGroupsEmptyRef) Then
					Record.AccessValuesGroup = AccessValuesGroupsEmptyRef;
				EndIf;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Object = Undefined Then
		AdditionalProperties = Undefined;
	Else
		AdditionalProperties = New Structure("LeadingObjectBeforeWrite", Object);
	EndIf;
	
	FixedFilter = New Structure;
	FixedFilter.Insert("AccessValue", Ref);
	FixedFilter.Insert("DataGroup", 0);
	
	Data = New Structure;
	Data.Insert("RegisterManager",       InformationRegisters.AccessValuesGroups);
	Data.Insert("NewRecords",            NewRecords);
	Data.Insert("FixedFilter",     FixedFilter);
	Data.Insert("AdditionalProperties", AdditionalProperties);
	
	BeginTransaction();
	Try
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateRecordSets(Data, HasCurrentChanges);
		If HasCurrentChanges Then
			StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
			HasChanges = True;
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Updates user groups to check allowed values for the Users and ExternalUsers access kinds.
// 
//
// <AccessValue field components>    <AccessValuesGroup field components>.
//                               <DataGroup field components>.
//
// A) for the Users access kind:
// {comparing with T.<field>}           {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentUser}.
//
// User                  1 - The same User.
//
//                               1 - User group of the same user.
//                                   
//
// B) for the External users access kind:
// {comparing with T.<field>}           {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentExternalUser}.
//
// External user          1 - The same External user.
//
//                               1 - External user group of the same external user.
//                                   
//
Procedure UpdateUsers(Users1 = Undefined,
                                HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT
	|	UserGroupCompositions.User AS AccessValue,
	|	UserGroupCompositions.UsersGroup AS AccessValuesGroup,
	|	1 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.Users)
	|	AND &UserFilterCriterion1
	|
	|UNION ALL
	|
	|SELECT
	|	UserGroupCompositions.User,
	|	UserGroupCompositions.UsersGroup,
	|	1,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.ExternalUsers)
	|	AND &UserFilterCriterion1";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",       "&UserFilterCriterion2"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",          "&UpdatedDataGroupFilterCriterion"));
	
	Query = New Query;
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValuesGroups");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, Users1, "Users",
		"&UserFilterCriterion1:UserGroupCompositions.User
		|&UserFilterCriterion2:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 1, "DataGroup",
		"&UpdatedDataGroupFilterCriterion:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.AccessValuesGroups);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FixedFilter",    New Structure("DataGroup", 1));
	
	AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
	
EndProcedure

// Updates user groups to check allowed values for the Users and ExternalUsers access kinds.
// 
//
// <AccessValue field components>    <AccessValuesGroup field components>.
//                               <DataGroup field components>.
//
// A) for the Users access kind:
// {comparing with T.<field>}           {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentUser}.
//
// User group          2 - The same User group.
//
//                               2 - A user of the same user group.
//                                   
//
// B) for the External users access kind:
// {comparing with T.<field>}           {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentExternalUser}.
//
// External user group  2 - The same External user group.
//
//                               2 - An external user from the same external user group.
//                                   
//
//
Procedure UpdateUserGroups(UserGroups = Undefined,
                                      HasChanges       = Undefined)
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT DISTINCT
	|	UserGroupCompositions.UsersGroup AS AccessValue,
	|	UserGroupCompositions.UsersGroup AS AccessValuesGroup,
	|	2 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.UserGroups)
	|	AND &UserGroupFilterCriterion1
	|
	|UNION ALL
	|
	|SELECT
	|	UserGroupCompositions.UsersGroup,
	|	UserGroupCompositions.User,
	|	2,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.UserGroups)
	|	AND VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.Users)
	|	AND &UserGroupFilterCriterion1
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	UserGroupCompositions.UsersGroup,
	|	UserGroupCompositions.UsersGroup,
	|	2,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.ExternalUsersGroups)
	|	AND &UserGroupFilterCriterion1
	|
	|UNION ALL
	|
	|SELECT
	|	UserGroupCompositions.UsersGroup,
	|	UserGroupCompositions.User,
	|	2,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.ExternalUsersGroups)
	|	AND VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.ExternalUsers)
	|	AND &UserGroupFilterCriterion1";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",         "&UserGroupFilterCriterion2"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",            "&UpdatedDataGroupFilterCriterion"));
	
	Query = New Query;
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValuesGroups");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, UserGroups, "UserGroups",
		"&UserGroupFilterCriterion1:UserGroupCompositions.UsersGroup
		|&UserGroupFilterCriterion2:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 2, "DataGroup",
		"&UpdatedDataGroupFilterCriterion:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.AccessValuesGroups);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FixedFilter",    New Structure("DataGroup", 2));
	
	AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
	
EndProcedure

// Updates user groups to check allowed values for the Users and ExternalUsers access kinds.
// 
//
// <AccessValue field components>    <AccessValuesGroup field components>.
//                               <DataGroup field components>.
//
// A) for the Users access kind:
// {comparing with T.<field>}           {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentUser}.
//
// Assignee group           3 - A user of the same assignee group.
//                                   
//
//                               3 - User group of the same assignee group user.
//                                   
//
// B) for the External users access kind:
// {comparing with T.<field>}           {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentExternalUser}.
//
// Assignee group           3 - An external user of the same assignee group.
//                                   
//
//                               3 - An external user group of an external user of the same assignee 
//                                   group.
//                                   
//
Procedure UpdatePerformersGroups(PerformersGroups = Undefined,
                                     Performers        = Undefined,
                                     HasChanges      = Undefined)
	
	SetPrivilegedMode(True);
	
	// Preparing a table of additional user groups - assignee groups (for example, tasks).
	// 
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	If PerformersGroups = Undefined
	   AND Performers        = Undefined Then
	
		ParameterContent = Undefined;
		ParameterValue   = Undefined;
	
	ElsIf PerformersGroups <> Undefined Then
		ParameterContent = "PerformersGroups";
		ParameterValue   = PerformersGroups;
		
	ElsIf Performers <> Undefined Then
		ParameterContent = "Performers";
		ParameterValue   = Performers;
	Else
		Raise
			NStr("ru = 'Ошибка в процедуре UpdatePerformersGroups
			           |модуля менеджера регистра сведений AccessValuesGroups.
			           |
			           |Указаны неверные параметры.'; 
			           |en = 'An error occurred in the UpdatePerformersGroups procedure
			           |of manager module of the AccessValuesGroups information register.
			           |
			           |Parameters are incorrect.'; 
			           |pl = 'Wystąpił błąd w procedurze UpdatePerformersGroups
			           |modułu menedżera rejestru informacji AccessValuesGroups.
			           |
			           |Określone są błędne parametry.';
			           |es_ES = 'Error en el procedimiento UpdatePerformersGroups
			           |del módulo de gestor del registro de información AccessValuesGroups.
			           |
			           |Se han indicado parámetros incorrectos.';
			           |es_CO = 'Error en el procedimiento UpdatePerformersGroups
			           |del módulo de gestor del registro de información AccessValuesGroups.
			           |
			           |Se han indicado parámetros incorrectos.';
			           |tr = 'Bilgi kayıt yöneticisi modülü Erişim değeri gruplarının 
			           |KullanıcıGruplarınıYenile prosedüründe bir hata oluştu. 
			           |
			           |Yanlış parametreler belirtildi.';
			           |it = 'Errore nella procedura UpdatePerformersGroups
			           |del modulo manager del registro informazioni AccessValuesGroups.
			           |
			           |Parametri non corretti.';
			           |de = 'Fehler in der Vorgehensweise AktualisierungAusführungsGruppen
			           |des Informationsregister-Manager-Moduls ZugriffsWerteGruppen.
			           |
			           |Falsche Parameter werden angegeben.'");
	EndIf;
	
	NoPerformerGroups = True;
	SSLSubsystemsIntegration.OnDeterminePerformersGroups(Query.TempTablesManager,
		ParameterContent, ParameterValue, NoPerformerGroups);
	
	If NoPerformerGroups Then
		RecordSet = CreateRecordSet();
		RecordSet.Filter.DataGroup.Set(3);
		RecordSet.Read();
		If RecordSet.Count() > 0 Then
			RecordSet.Clear();
			RecordSet.Write();
			HasChanges = True;
		EndIf;
		Return;
	EndIf;
	
	// Preparing selected links of assignees and assignee groups.
	Query.SetParameter("EmptyValueGroupsReferences",
		AccessManagementInternalCached.BlankSpecifiedTypesRefsTable(
			"InformationRegister.AccessValuesGroups.Dimension.AccessValuesGroup").Get());
	
	TemporaryTablesQueriesText =
	"SELECT
	|	EmptyValueGroupsReferences.EmptyRef
	|INTO EmptyValueGroupsReferences
	|FROM
	|	&EmptyValueGroupsReferences AS EmptyValueGroupsReferences
	|
	|INDEX BY
	|	EmptyValueGroupsReferences.EmptyRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	PerformerGroupsTable.PerformersGroup,
	|	PerformerGroupsTable.User
	|INTO AssigneeGroupsUsers
	|FROM
	|	PerformerGroupsTable AS PerformerGroupsTable
	|		INNER JOIN EmptyValueGroupsReferences AS EmptyValueGroupsReferences
	|		ON (VALUETYPE(PerformerGroupsTable.PerformersGroup) = VALUETYPE(EmptyValueGroupsReferences.EmptyRef))
	|			AND PerformerGroupsTable.PerformersGroup <> EmptyValueGroupsReferences.EmptyRef
	|WHERE
	|	VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.UserGroups)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.Users)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.ExternalUsers)
	|	AND VALUETYPE(PerformerGroupsTable.User) = TYPE(Catalog.Users)
	|	AND PerformerGroupsTable.User <> VALUE(Catalog.Users.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	PerformerGroupsTable.PerformersGroup,
	|	PerformerGroupsTable.User AS ExternalUser
	|INTO ExternalPerformerGroupUsers
	|FROM
	|	PerformerGroupsTable AS PerformerGroupsTable
	|		INNER JOIN EmptyValueGroupsReferences AS EmptyValueGroupsReferences
	|		ON (VALUETYPE(PerformerGroupsTable.PerformersGroup) = VALUETYPE(EmptyValueGroupsReferences.EmptyRef))
	|			AND PerformerGroupsTable.PerformersGroup <> EmptyValueGroupsReferences.EmptyRef
	|WHERE
	|	VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.UserGroups)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.Users)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.ExternalUsers)
	|	AND VALUETYPE(PerformerGroupsTable.User) = TYPE(Catalog.ExternalUsers)
	|	AND PerformerGroupsTable.User <> VALUE(Catalog.ExternalUsers.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP PerformerGroupsTable";
	
	If PerformersGroups = Undefined
	   AND Performers <> Undefined Then
		
		QueryText =
		"SELECT
		|	AssigneeGroupsUsers.PerformersGroup
		|FROM
		|	AssigneeGroupsUsers AS AssigneeGroupsUsers
		|
		|UNION
		|
		|SELECT
		|	ExternalPerformerGroupUsers.PerformersGroup
		|FROM
		|	ExternalPerformerGroupUsers AS ExternalPerformerGroupUsers";
		
		Query.Text = TemporaryTablesQueriesText + "
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|" + QueryText;
		
		QueriesResults = Query.ExecuteBatch();
		Count = QueriesResults.Count();
		
		PerformersGroups = QueriesResults[Count-1].Unload().UnloadColumn("PerformersGroup");
		TemporaryTablesQueriesText = Undefined;
	EndIf;
	
	QueryText =
	"SELECT
	|	AssigneeGroupsUsers.PerformersGroup AS AccessValue,
	|	AssigneeGroupsUsers.User AS AccessValuesGroup,
	|	3 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	AssigneeGroupsUsers AS AssigneeGroupsUsers
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	AssigneeGroupsUsers.PerformersGroup,
	|	UserGroupCompositions.UsersGroup,
	|	3,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	AssigneeGroupsUsers AS AssigneeGroupsUsers
	|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON AssigneeGroupsUsers.User = UserGroupCompositions.User
	|			AND (VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.UserGroups))
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalPerformerGroupUsers.PerformersGroup,
	|	ExternalPerformerGroupUsers.ExternalUser,
	|	3,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	ExternalPerformerGroupUsers AS ExternalPerformerGroupUsers
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	ExternalPerformerGroupUsers.PerformersGroup,
	|	UserGroupCompositions.UsersGroup,
	|	3,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	ExternalPerformerGroupUsers AS ExternalPerformerGroupUsers
	|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON ExternalPerformerGroupUsers.ExternalUser = UserGroupCompositions.User
	|			AND (VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.ExternalUsersGroups))";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",         "&AssigneeGroupFilterCriterion"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",            "&UpdatedDataGroupFilterCriterion"));
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValuesGroups", TemporaryTablesQueriesText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, PerformersGroups, "PerformersGroups",
		"&AssigneeGroupFilterCriterion:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 3, "DataGroup",
		"&UpdatedDataGroupFilterCriterion:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.AccessValuesGroups);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FixedFilter",    New Structure("DataGroup", 3));
	
	AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
	
EndProcedure

// Updates user groups to check allowed values for the Users and ExternalUsers access kinds.
// 
//
// <AccessValue field components>    <AccessValuesGroup field components>.
//                               <DataGroup field components>.
//
// For the External users access kind:
// {comparing with T.<field>}           {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentExternalUser}.
//
// Authorization object            4 - An external user of the same authorization object.
//                                   
//
//                               4 - An external user group of an external user of the same 
//                                   authorization object.
//                                   
//
Procedure UpdateAuthorizationObjects(AuthorizationObjects = Undefined, HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("EmptyValueReferences",
		AccessManagementInternalCached.BlankSpecifiedTypesRefsTable(
			"InformationRegister.AccessValuesGroups.Dimension.AccessValue").Get());
	
	TemporaryTablesQueriesText =
	"SELECT
	|	EmptyValueReferences.EmptyRef
	|INTO EmptyValueReferences
	|FROM
	|	&EmptyValueReferences AS EmptyValueReferences
	|
	|INDEX BY
	|	EmptyValueReferences.EmptyRef";
	
	QueryText =
	"SELECT
	|	CAST(UserGroupCompositions.User AS Catalog.ExternalUsers).AuthorizationObject AS AccessValue,
	|	UserGroupCompositions.UsersGroup AS AccessValuesGroup,
	|	4 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		INNER JOIN Catalog.ExternalUsers AS ExternalUsers
	|		ON (VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.ExternalUsers))
	|			AND UserGroupCompositions.User = ExternalUsers.Ref
	|		INNER JOIN EmptyValueReferences AS EmptyValueReferences
	|		ON (VALUETYPE(ExternalUsers.AuthorizationObject) = VALUETYPE(EmptyValueReferences.EmptyRef))
	|			AND (ExternalUsers.AuthorizationObject <> EmptyValueReferences.EmptyRef)
	|WHERE
	|	&AuthorizationObjectFilterCriterion1";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",         "&AuthorizationObjectFilterCriterion2"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",            "&UpdatedDataGroupFilterCriterion"));
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValuesGroups", TemporaryTablesQueriesText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AuthorizationObjects, "AuthorizationObjects",
		"&AuthorizationObjectFilterCriterion1:ExternalUsers.AuthorizationObject
		|&AuthorizationObjectFilterCriterion2:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 4, "DataGroup",
		"&UpdatedDataGroupFilterCriterion:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.AccessValuesGroups);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FixedFilter",    New Structure("DataGroup", 4));
	
	AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
	
EndProcedure

#EndRegion

#EndIf