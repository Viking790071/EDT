#Region Public

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used to check rights.

// Checks whether the user has a role in one of the profiles of the access groups, to which they 
// belong. For example, ViewEventLog role, UnpostedDocumentsPrint role.
//
// If an object (or access value sets) is specified, it is required to check whether the access 
// group provides the Read right for the specified object (or the specified access value set is allowed).
//
// Parameters:
//  Role - String - a role name.
//
//  ObjectRef - Ref - a reference to the object, for which the access value sets are filled to check 
//                   the Read right.
//                 - ValueTable - a table of arbitrary access value sets with the following columns:
//                     * SetNumber - Number - a number grouping multiple rows in a separate set.
//                     * AccessKind - String - an access kind name specified in the overridable module.
//                     * AccessValue - Ref - a reference to the access value type specified in the overridable module.
//                       You can receive a blank prepared table using the function.
//                       AccessValuesSetsTable of the AccessManagement common module (do not fill 
//                       the Read and Update columns).
//
//  User - CatalogRef.Users, CatalogRef.ExternalUsers, Undefined - if the parameter is not specified, 
//                   the right is checked for the current user.
//
// Returns:
//  Boolean - if True, the user has a role with restrictions.
//
Function HasRole(Val Role, Val ObjectRef = Undefined, Val User = Undefined) Export
	
	User = ?(ValueIsFilled(User), User, Users.AuthorizedUser());
	If Users.IsFullUser(User) Then
		Return True;
	EndIf;
	Role = Common.MetadataObjectID("Role." + Role);
	
	SetPrivilegedMode(True);
	
	If ObjectRef = Undefined OR NOT LimitAccessAtRecordLevel() Then
		// Checking that the role is assigned to the user using an access group profile.
		Query = New Query;
		Query.SetParameter("AuthorizedUser", User);
		Query.SetParameter("Role", Role);
		Query.Text =
		"SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	Catalog.AccessGroups.Users AS AccessGroupsUsers
		|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|		ON (UserGroupCompositions.User = &AuthorizedUser)
		|			AND (UserGroupCompositions.UsersGroup = AccessGroupsUsers.User)
		|			AND (UserGroupCompositions.Used)
		|			AND (NOT AccessGroupsUsers.Ref.DeletionMark)
		|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS AccessGroupProfilesRoles
		|		ON AccessGroupsUsers.Ref.Profile = AccessGroupProfilesRoles.Ref
		|			AND (AccessGroupProfilesRoles.Role = &Role)
		|			AND (NOT AccessGroupProfilesRoles.Ref.DeletionMark)";
		Return NOT Query.Execute().IsEmpty();
	EndIf;
		
	If TypeOf(ObjectRef) = Type("ValueTable") Then
		AccessValuesSets = ObjectRef.Copy();
	Else
		AccessValuesSets = AccessValuesSetsTable();
		ObjectRef.GetObject().FillAccessValuesSets(AccessValuesSets);
		// Selecting the access value sets used to check the Read right.
		ReadSetsRows = AccessValuesSets.FindRows(New Structure("Read", True));
		SetsNumbers = New Map;
		For each Row In ReadSetsRows Do
			SetsNumbers.Insert(Row.SetNumber, True);
		EndDo;
		Index = AccessValuesSets.Count()-1;
		While Index > 0 Do
			If SetsNumbers[AccessValuesSets[Index].SetNumber] = Undefined Then
				AccessValuesSets.Delete(Index);
			EndIf;
			Index = Index - 1;
		EndDo;
		AccessValuesSets.FillValues(False, "Read, Update");
	EndIf;
	
	// Adjusting access value sets.
	AccessKindsNames = AccessManagementInternalCached.AccessKindsProperties().ByNames;
	
	For each Row In AccessValuesSets Do
		
		If Row.AccessKind = "" Then
			Continue;
		EndIf;
		
		If Upper(Row.AccessKind) = Upper("ReadRight")
		 OR Upper(Row.AccessKind) = Upper("EditRight") Then
			
			If TypeOf(Row.AccessValue) <> Type("CatalogRef.MetadataObjectIDs") Then
				If Common.IsReference(TypeOf(Row.AccessValue)) Then
					Row.AccessValue = Common.MetadataObjectID(TypeOf(Row.AccessValue));
				Else
					Row.AccessValue = Undefined;
				EndIf;
			EndIf;
			
			If Upper(Row.AccessKind) = Upper("EditRight") Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Ошибка в функции HasRole модуля AccessManagement.
					           |В наборе значений доступа указан вид доступа UpdateRight
					           |таблицы с идентификатором ""%1"".
					           |В ограничении проверки роли (как дополнительного права)
					           |может быть зависимость только от права Read.'; 
					           |en = 'An error occurred in the HasRole function of the AccessManagement module.
					           |Access kind UpdateRight
					           |of table with ID ""%1"" is specified in the access value set.
					           |Restriction of the role check (as an additional right)
					           |can depend only on the Read right.'; 
					           |pl = 'Wystąpił błąd w funkcji HasRole modułu AccessManagement.
					           |W zestawie wartości dostępu określono rodzaj dostępu
					           |UpdateRight dla tabeli z identyfikatorem ""%1"".
					           |W kontrolach ograniczeń rola (jako dodatkowe prawo)
					           |może zależeć tylko od prawa odczytu.';
					           |es_ES = 'Ha ocurrido un error en la función HasRole del módulo AccessManagement.
					           |En el conjunto de valores de acceso el tipo de acceso
					           |EditingRight está especificado de la tabla con el identificador ""%1"".
					           |En las revisiones del rol de restricciones (como un derecho adicional)
					           |puede depender solo en el derecho de Lectura.';
					           |es_CO = 'Ha ocurrido un error en la función HasRole del módulo AccessManagement.
					           |En el conjunto de valores de acceso el tipo de acceso
					           |EditingRight está especificado de la tabla con el identificador ""%1"".
					           |En las revisiones del rol de restricciones (como un derecho adicional)
					           |puede depender solo en el derecho de Lectura.';
					           |tr = 'AccessManagement modülünün HasRole işlevinde bir hata oluştu. 
					           |Erişim değerlerinde UpdateRight%1 erişim türü "
" kimliğine sahip tablodan belirtilir. 
					           |Kısıtlama rolü kontrollerinde (ek bir hak olarak) kısıtlama sadece 
					           |Okuma hakkına bağlı olabilir.';
					           |it = 'Si è verificato un errore nella funzione HasRole del modulo AccessManagement.
					           |Il tipo di accesso UpdateRight
					           |della tabella con ID ""%1"" è indicato nel set di valori di accesso.
					           |La restrizione sul controllo del ruolo (come diritto aggiuntivo)
					           |può dipendere solo dal diritto Lettura.';
					           |de = 'In der Funktion HatRolle des Moduls AccessManagement ist ein Fehler aufgetreten.
					           |In den eingestellten Zugriffswerten ist die Zugriffsart UpdateRight
					           |der Tabelle mit der ID ""%1"" angegeben.
					           |In der Restriktion können Rollenprüfungen (als zusätzliches Recht)
					           |nur vom Leserecht abhängen.'"),
					Row.AccessValue);
			EndIf;
		ElsIf AccessKindsNames.Get(Row.AccessKind) <> Undefined
		      OR Row.AccessKind = "RightsSettings" Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка в функции HasRole модуля AccessManagement.
				           |Набор значений доступа содержит известный вид доступа ""%1"",
				           |который не требуется указывать.
				           |
				           |Указывать требуется только специальные виды доступа
				           |""ReadRight"", ""UpdateRight"", если они используются.'; 
				           |en = 'An error occurred in the HasRole function of the AccessManagement module.
				           |Access value set contains known access kind ""%1""
				           |, which is not required.
				           |
				           |Specify only special access kinds
				           |ReadRight, UpdateRight if they are used.'; 
				           |pl = 'Wystąpił błąd w funkcji HasRole modułu AccessManagement.
				           |Zestaw znaczeń dostępu posiada nieznany rodzaj dostępu ""%1"",
				           |którego nie należy podawać.
				           |
				           |Należy podać jedynie specjalne rodzaje dostępu
				           |ReadRight, UpdateRight, jeżeli są używane.';
				           |es_ES = 'Ha ocurrido un error en la función HasRole del módulo AccessManagement.
				           |En el conjunto de valores de acceso hay tipo de acceso conocido ""%1"" 
				           |que no hay que especificar.
				           |
				           |Hay que especificar solo los tipos de acceso especiales
				           |""ReadingRight"", ""ChangingRight"", si se utilizan.';
				           |es_CO = 'Ha ocurrido un error en la función HasRole del módulo AccessManagement.
				           |En el conjunto de valores de acceso hay tipo de acceso conocido ""%1"" 
				           |que no hay que especificar.
				           |
				           |Hay que especificar solo los tipos de acceso especiales
				           |""ReadingRight"", ""ChangingRight"", si se utilizan.';
				           |tr = 'AccessManagement modülünün HasRole işlevinde bir hata oluştu.
				           |Erişim değerleri kümesi belirlemeniz gereken ""%1""
				           |bilinen erişim türünü içerir.
				           |
				           |Kullanıldıkları zaman sadece ""ReadRight"", ""UpdateRight""
				           |özel erişim türlerini belirtin.';
				           |it = 'Si è verificato un errore nella funzione HasRola del modulo AccessManagement.
				           |Il set di valori di accesso contiene tipi di accesso conosciuti ""%1""
				           |, non richiesti.
				           |
				           |Indicare soltanto i tipi di accesso speciale
				           |ReadRight e UpdateRight, se utilizzati.';
				           |de = 'In der Funktion HasRole des Moduls AccessManagement ist ein Fehler aufgetreten.
				           |Zugriffswerte enthalten die bekannte Zugriffsart ""%1"",
				           |die Sie nicht angeben sollten.
				           |
				           |Spezifizieren Sie nur spezielle Zugriffs
				           |arten ""ReadRight"", ""UpdateRight"", wenn sie verwendet werden.'"),
				Row.AccessKind);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка в функции HasRole модуля AccessManagement.
				           |Набор значений доступа содержит неизвестный вид доступа ""%1"".'; 
				           |en = 'An error occurred in the HasRole function of the AccessManagement module.
				           |Access value set contains unknown access kind ""%1"".'; 
				           |pl = 'Wystąpił błąd w funkcji HasRole modułu AccessManagement.
				           |Zestaw znaczeń dostępu posiada nieznany rodzaj dostępu ""%1"".';
				           |es_ES = 'Ha ocurrido un error en la función HasRole del módulo AccessManagement.
				           |Conjunto de valores de acceso tiene el tipo de acceso desconocido ""%1"".';
				           |es_CO = 'Ha ocurrido un error en la función HasRole del módulo AccessManagement.
				           |Conjunto de valores de acceso tiene el tipo de acceso desconocido ""%1"".';
				           |tr = 'AccessManagement modülünün HasRole işlevinde bir hata oluştu.
				           | Erişim değerleri kümesi bilinmeyen erişim türünü ""%1"" içerir.';
				           |it = 'Si è verificato un errore nella funzione HasRole del modulo AccessManagement.
				           |Il set di valori di accesso contiene un tipo di accesso sconosciuto ""%1"".';
				           |de = 'In der Funktion HasRole des Moduls AccessManagement ist ein Fehler aufgetreten.
				           |Zugriffswerte enthalten die unbekannte Zugriffsart ""%1"".'"),
				Row.AccessKind);
		EndIf;
		
		Row.AccessKind = "";
	EndDo;
	
	// Adding internal fields to an access value set.
	AccessManagementInternal.PrepareAccessValuesSetsForWrite(Undefined, AccessValuesSets, True);
	
	// Checking whether the role is assigned to the user from an access group using a profile with 
	// allowed access value sets.
	
	Query = New Query;
	Query.SetParameter("AuthorizedUser", User);
	Query.SetParameter("Role", Role);
	Query.SetParameter("AccessValuesSets", AccessValuesSets);
	Query.SetParameter("RightsSettingsOwnersTypes", SessionParameters.RightsSettingsOwnersTypes);
	Query.Text =
	"SELECT DISTINCT
	|	AccessValuesSets.SetNumber,
	|	AccessValuesSets.AccessValue,
	|	AccessValuesSets.ValueWithoutGroups,
	|	AccessValuesSets.StandardValue
	|INTO AccessValuesSets
	|FROM
	|	&AccessValuesSets AS AccessValuesSets
	|
	|INDEX BY
	|	AccessValuesSets.SetNumber,
	|	AccessValuesSets.AccessValue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccessGroupsUsers.Ref AS Ref
	|INTO AccessGroups
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON (UserGroupCompositions.User = &AuthorizedUser)
	|			AND (UserGroupCompositions.UsersGroup = AccessGroupsUsers.User)
	|			AND (UserGroupCompositions.Used)
	|			AND (NOT AccessGroupsUsers.Ref.DeletionMark)
	|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS AccessGroupProfilesRoles
	|		ON AccessGroupsUsers.Ref.Profile = AccessGroupProfilesRoles.Ref
	|			AND (AccessGroupProfilesRoles.Role = &Role)
	|			AND (NOT AccessGroupProfilesRoles.Ref.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Sets.SetNumber
	|INTO SetsNumbers
	|FROM
	|	AccessValuesSets AS Sets
	|
	|INDEX BY
	|	Sets.SetNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	AccessGroups AS AccessGroups
	|WHERE
	|	NOT(TRUE IN
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						SetsNumbers AS SetsNumbers
	|					WHERE
	|						TRUE IN
	|							(SELECT TOP 1
	|								TRUE
	|							FROM
	|								AccessValuesSets AS ValueSets
	|							WHERE
	|								ValueSets.SetNumber = SetsNumbers.SetNumber
	|								AND NOT TRUE IN
	|										(SELECT TOP 1
	|											TRUE
	|										FROM
	|											InformationRegister.DefaultAccessGroupsValues AS DefaultValues
	|										WHERE
	|											DefaultValues.AccessGroup = AccessGroups.Ref
	|											AND VALUETYPE(DefaultValues.AccessValuesType) = VALUETYPE(ValueSets.AccessValue)
	|											AND DefaultValues.NoSettings = TRUE)))
	|				AND NOT TRUE IN
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							SetsNumbers AS SetsNumbers
	|						WHERE
	|							TRUE IN
	|								(SELECT TOP 1
	|									TRUE
	|								FROM
	|									AccessValuesSets AS ValueSets
	|								WHERE
	|									ValueSets.SetNumber = SetsNumbers.SetNumber
	|									AND NOT TRUE IN
	|											(SELECT TOP 1
	|												TRUE
	|											FROM
	|												InformationRegister.DefaultAccessGroupsValues AS DefaultValues
	|											WHERE
	|												DefaultValues.AccessGroup = AccessGroups.Ref
	|												AND VALUETYPE(DefaultValues.AccessValuesType) = VALUETYPE(ValueSets.AccessValue)
	|												AND DefaultValues.NoSettings = TRUE))
	|							AND NOT FALSE IN
	|									(SELECT TOP 1
	|										FALSE
	|									FROM
	|										AccessValuesSets AS ValueSets
	|									WHERE
	|										ValueSets.SetNumber = SetsNumbers.SetNumber
	|										AND NOT CASE
	|												WHEN ValueSets.ValueWithoutGroups
	|													THEN TRUE IN
	|															(SELECT TOP 1
	|																TRUE
	|															FROM
	|																InformationRegister.DefaultAccessGroupsValues AS DefaultValues
	|																	LEFT JOIN InformationRegister.AccessGroupsValues AS Values
	|																	ON
	|																		Values.AccessGroup = AccessGroups.Ref
	|																			AND Values.AccessValue = ValueSets.AccessValue
	|															WHERE
	|																DefaultValues.AccessGroup = AccessGroups.Ref
	|																AND VALUETYPE(DefaultValues.AccessValuesType) = VALUETYPE(ValueSets.AccessValue)
	|																AND ISNULL(Values.ValueAllowed, DefaultValues.AllAllowed))
	|												WHEN ValueSets.StandardValue
	|													THEN CASE
	|															WHEN TRUE IN
	|																	(SELECT TOP 1
	|																		TRUE
	|																	FROM
	|																		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|																	WHERE
	|																		AccessValuesGroups.AccessValue = ValueSets.AccessValue
	|																		AND AccessValuesGroups.AccessValuesGroup = &AuthorizedUser)
	|																THEN TRUE
	|															ELSE TRUE IN
	|																	(SELECT TOP 1
	|																		TRUE
	|																	FROM
	|																		InformationRegister.DefaultAccessGroupsValues AS DefaultValues
	|																			INNER JOIN InformationRegister.AccessValuesGroups AS ValueGroups
	|																			ON
	|																				ValueGroups.AccessValue = ValueSets.AccessValue
	|																					AND DefaultValues.AccessGroup = AccessGroups.Ref
	|																					AND VALUETYPE(DefaultValues.AccessValuesType) = VALUETYPE(ValueSets.AccessValue)
	|																			LEFT JOIN InformationRegister.AccessGroupsValues AS Values
	|																			ON
	|																				Values.AccessGroup = AccessGroups.Ref
	|																					AND Values.AccessValue = ValueGroups.AccessValuesGroup
	|																	WHERE
	|																		ISNULL(Values.ValueAllowed, DefaultValues.AllAllowed))
	|														END
	|												WHEN ValueSets.AccessValue = VALUE(Enum.AdditionalAccessValues.AccessAllowed)
	|													THEN TRUE
	|												WHEN ValueSets.AccessValue = VALUE(Enum.AdditionalAccessValues.AccessDenied)
	|													THEN FALSE
	|												WHEN VALUETYPE(ValueSets.AccessValue) = TYPE(Catalog.MetadataObjectIDs)
	|													THEN TRUE IN
	|															(SELECT TOP 1
	|																TRUE
	|															FROM
	|																InformationRegister.AccessGroupsTables AS AccessGroupsTablesObjectRightCheck
	|															WHERE
	|																AccessGroupsTablesObjectRightCheck.AccessGroup = AccessGroups.Ref
	|																AND AccessGroupsTablesObjectRightCheck.Table = ValueSets.AccessValue)
	|												ELSE TRUE IN
	|															(SELECT TOP 1
	|																TRUE
	|															FROM
	|																InformationRegister.ObjectsRightsSettings AS RightsSettings
	|																	INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|																	ON
	|																		SettingsInheritance.Object = ValueSets.AccessValue
	|																			AND RightsSettings.Object = SettingsInheritance.Parent
	|																			AND SettingsInheritance.UsageLevel < RightsSettings.ReadingPermissionLevel
	|																	INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|																	ON
	|																		UserGroupCompositions.User = &AuthorizedUser
	|																			AND UserGroupCompositions.UsersGroup = RightsSettings.User)
	|														AND NOT FALSE IN
	|																(SELECT TOP 1
	|																	FALSE
	|																FROM
	|																	InformationRegister.ObjectsRightsSettings AS RightsSettings
	|																		INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|																		ON
	|																			SettingsInheritance.Object = ValueSets.AccessValue
	|																				AND RightsSettings.Object = SettingsInheritance.Parent
	|																				AND SettingsInheritance.UsageLevel < RightsSettings.ReadingProhibitionLevel
	|																		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|																		ON
	|																			UserGroupCompositions.User = &AuthorizedUser
	|																				AND UserGroupCompositions.UsersGroup = RightsSettings.User)
	|											END)))";
	
	Return NOT Query.Execute().IsEmpty();
	
EndFunction

// Checks whether object right permissions are set for the user.
//  For example, you can set the RightsManagement, Read, and FoldersChange rights for a file folder,
// the Read right is both the right for the file folder and the right for the files.
//
// Parameters:
//  Right - String - a right name as it is specified in the 
//                   OnFillAvailableRightsForObjectsRightsSettings procedure of the AccessManagementOverridable common module.
//
//  ObjectRef - CatalogRef, ChartOfCharacteristicTypesRef - reference to one of the right owners 
//                   specified in the OnFillAvailableRightsForObjectsRightsSettings procedure of the 
//                   AccessManagementOverridable common module; for example, a reference to file folder.
//
//  User - CatalogRef.Users, CatalogRef.ExternalUsers, Undefined - if the parameter is not specified, 
//                   the right is checked for the current user.
//
// Returns:
//  Boolean - if True, the right permission is set up according to all allowed and prohibited 
//           settings in the hierarchy.
//
Function HasRight(Right, ObjectRef, User = Undefined) Export
	
	User = ?(ValueIsFilled(User), User, Users.AuthorizedUser());
	If Users.IsFullUser(User) Then
		Return True;
	EndIf;
	
	If Not LimitAccessAtRecordLevel() Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	AvailableRights = AccessManagementInternalCached.RightsForObjectsRightsSettingsAvailable();
	RightsDetails = AvailableRights.ByTypes.Get(TypeOf(ObjectRef));
	
	If RightsDetails = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не найдено описание возможных прав для таблицы ""%1""'; en = 'Description of available rights for table %1 is not found.'; pl = 'Opis możliwych uprawnień dla tabeli ""%1"" nie został znaleziony';es_ES = 'Descripción de los posibles derechos para la tabla ""%1"" no se ha encontrado';es_CO = 'Descripción de los posibles derechos para la tabla ""%1"" no se ha encontrado';tr = '""%1"" tablosu için olası hakların açıklanması bulunmadı';it = 'La descrizione dei permessi disponibile per la tabella %1 non è stato trovata.';de = 'Beschreibung der möglichen Rechte für die Tabelle ""%1"" wurde nicht gefunden'"),
			ObjectRef.Metadata().FullName());
	EndIf;
	
	RightDetails = RightsDetails.Get(Right);
	
	If RightDetails = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не найдено описание права ""%1"" для таблицы ""%2""'; en = 'Description of right %1 for table %2 is not found'; pl = 'Prawidłowy opis ""%1"" dla tabeli ""%2"" nie został znaleziony';es_ES = 'Descripción del derecho ""%1"" para la tabla ""%2"" no se ha encontrado';es_CO = 'Descripción del derecho ""%1"" para la tabla ""%2"" no se ha encontrado';tr = '""%1"" tablosu için ""%2"" hakkın açıklaması bulunmadı';it = 'La descrizione dei permessi %1 per la tabella %2 non è stato trovata.';de = 'Beschreibung der Rechte ""%1"" für Tabelle ""%2"" wurde nicht gefunden'"),
			Right, ObjectRef.Metadata().FullName());
	EndIf;
	
	If NOT ValueIsFilled(ObjectRef) Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("ObjectRef", ObjectRef);
	Query.SetParameter("User", User);
	Query.SetParameter("Right", Right);
	
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.ObjectsRightsSettings AS RightsSettings
	|					INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|					ON
	|						SettingsInheritance.Object = &ObjectRef
	|							AND RightsSettings.UserRight = &Right
	|							AND SettingsInheritance.UsageLevel < RightsSettings.RightPermissionLevel
	|							AND RightsSettings.Object = SettingsInheritance.Parent
	|					INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|					ON
	|						UserGroupCompositions.User = &User
	|							AND UserGroupCompositions.UsersGroup = RightsSettings.User)
	|	AND NOT FALSE IN
	|				(SELECT TOP 1
	|					FALSE
	|				FROM
	|					InformationRegister.ObjectsRightsSettings AS RightsSettings
	|						INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|						ON
	|							SettingsInheritance.Object = &ObjectRef
	|								AND RightsSettings.UserRight = &Right
	|								AND SettingsInheritance.UsageLevel < RightsSettings.RightProhibitionLevel
	|								AND RightsSettings.Object = SettingsInheritance.Parent
	|						INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|						ON
	|							UserGroupCompositions.User = &User
	|								AND UserGroupCompositions.UsersGroup = RightsSettings.User)";
	
	Return NOT Query.Execute().IsEmpty();
	
EndFunction

// Checks if reading of an existing object from the database is allowed at the rights level and 
// record level for the current user.
//
// Warning: if the subsystem operates in the standard restriction mode and not in the universal 
// restriction mode, only the right to the table is checked without checking the right at the record 
// level.
// 
// Parameters:
//  DataDetails - CatalogRef,
//                   DocumentRef,
//                   ChartOfCharacteristicTypesRef,
//                   ChartOfAccountsRef,
//                   ChartOfCalculationTypesRef,
//                   BusinessProcessRef,
//                   TaskRef,
//                   ExchangePlanRef - a reference to the object to be checked.
//                 - InformationRegisterRecordKey,
//                   AccumulationRegisterRecordKey,
//                   AccountingRegisterRecordKey,
//                   CalculationRegisterRecordKey - a record key to be checked.
//
Function ReadingAllowed(DataDetails) Export
	
	Return AccessManagementInternal.AccessAllowed(DataDetails, False);
	
EndFunction

// See AccessManagement.ReadingAllowed. 
Function EditionAllowed(DataDetails) Export
	
	Return AccessManagementInternal.AccessAllowed(DataDetails, True);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures for including and excluding a user in access group profile.

// Assigning an access group profile to a user by including them in a personal access group (only 
// for simplified setting of rights).
//
// Parameters:
//  User - CatalogRef.Users, CatalogRef.ExternalUsers - a required user.
//  Profile - CatalogRef.AccessGroupsProfiles - a profile, for which you need to find or create a 
//                   personal access group and include a user in it.
//               - UUID - UUID of a supplied profile, using which you need to find an access group 
//                   profile.
//               - String - a supplied profile name, using which you need to find an access group 
//                   profile.
//
Procedure EnableProfileForUser(User, Profile) Export
	EnableDisableUserProfile(User, Profile, True);
EndProcedure

// Canceling assignment of an access group profile to a user by excluding them from a personal 
// access group (only for simplified setting of rights).
//
// Parameters:
//  User - CatalogRef.Users, CatalogRef.ExternalUsers - a required user.
//  Profile - CatalogRef.AccessGroupsProfiles - a profile, for which you need to find or create a 
//                    personal access group and include a user in it.
//               - UUID - UUID of a supplied profile, using which you need to find an access group 
//                    profile.
//               - String - a supplied profile name, using which you need to find an access group 
//                    profile.
//               - Undefined - disable all user profiles.
//
Procedure DisableUserProfile(User, Profile = Undefined) Export
	EnableDisableUserProfile(User, Profile, False);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used to get common subsystem settings.

// Checks whether access restriction is used at the record level.
//
// Returns:
//  Boolean - if True, access is restricted at the record level.
//
Function LimitAccessAtRecordLevel() Export
	
	SetPrivilegedMode(True);
	
	Return GetFunctionalOption("LimitAccessAtRecordLevel");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used for setting managed form interface.

// The OnReadAtServer form event handler, which is embedded into item forms of catalogs, documents, 
// register records, and other objects to lock the form if data changes are denied.
//
// Parameters:
//  Form               - ClientApplicationForm - an item form of an object or a register record form.
//
//  CurrentObject       - CatalogObject,
//                        DocumentObject,
//                        ChartOfCharacteristicTypesObject,
//                        ChartOfAccountsObject,
//                        ChartOfCalculationTypesObject,
//                        BusinessProcessObject,
//                        TaskObject,
//                        ExchangePlanObject - an object to be checked.
//                      - InformationRegisterRecordManager,
//                        AccumulationRegisterRecordManager,
//                        AccountingRegisterRecordManager,
//                        CalculationRegisterRecordManager - a manager of the record being checked.
//
Procedure OnReadAtServer(Form, CurrentObject) Export
	
	If EditionAllowed(CurrentObject) Then
		Return;
	EndIf;
	
	Form.ReadOnly = True;
	
EndProcedure

// The AfterWriteAtServer form event handler that is built in item forms of catalogs, documents, 
// register records and so on, to accelerate the start of dependent object access update when update 
// is scheduled.
//
// Parameters:
//  Form           - ClientApplicationForm - an object item form or a register record form.
//
//  CurrentObject   - CatalogObject,
//                    DocumentObject,
//                    ChartOfCharacteristicTypesObject,
//                    ChartOfAccountsObject,
//                    ChartOfCalculationTypesObject,
//                    BusinessProcessObject,
//                    TaskObject,
//                    ExchangePlanObject - an object to be checked.
//                  - InformationRegisterRecordManager,
//                    AccumulationRegisterRecordManager,
//                    AccountingRegisterRecordManager,
//                    CalculationRegisterRecordManager - a manager of the record being checked.
//
//  WriteParameters - Structure - a standard parameter that is passed to event handler.
//
Procedure AfterWriteAtServer(Form, CurrentObject, WriteParameters) Export
	
	AccessManagementInternal.StartAccessUpdate();
	
EndProcedure

// Configures a form of access value, which uses access value groups to select allowed values in 
// user access groups.
//
// Supported only when a single access value group is selected for an access value.
// 
//
// For the AccessGroup form item associated with the AccessGroup attribute, it sets the access value 
// group list to the selection parameter providing access to change the access values.
//
// Upon creating new access values, if the number of access value groups, which provide access to 
// change the access value, is zero, an exception will be raised.
//
// If the database already contains an access value group that does not provide access to change the 
// access value or the number of access value groups, which provide access to change the access 
// values, is zero, the ViewOnly form parameter is set to True.
//
// If neither a restriction at the record level or restriction by access kind is used, the form item 
// is hidden.
//
// Parameters:
//  Form - ClientApplicationForm - a form of an access value that uses groups to select allowed values.
//                   
//
//  Attribute - Undefined - it is the name of the Object.AccessGroup form attribute.
//                 - String - a form attribute name containing the access group.
//
//  Items - Undefined - the AccessGroup form item name.
//                 - String - a form item name.
//                 - Array - form item names.
//
//  ValueType - Undefined - getting a type from the Object.Ref form attribute.
//                 - Type - an access value reference type.
//
//  CreateNewAccessValue - Undefined - getting the NOT ValueFilled(Form.Object.Ref) value
//                   to determine whether a new access value is being created or not.
//                 - Boolean - the specified value is used.
//
Procedure OnCreateAccessValueForm(Form,
                                          Attribute       = Undefined,
                                          Items       = Undefined,
                                          ValueType    = Undefined,
                                          CreateNewAccessValue = Undefined) Export
	
	ErrorTitle =
		NStr("ru = 'Ошибка в процедуре OnCreateAccessValueForm
		           |общего модуля AccessManagement.'; 
		           |en = 'An error occurred in the OnCreateAccessValueForm procedure
		           |of the AccessManagement common module.'; 
		           |pl = 'Wystąpił błąd w procedurze OnCreateAccessValueForm 
		           | modułu ogólnego AccessManagement.';
		           |es_ES = 'Ha ocurrido un error en el procedimiento OnCreateAccessValueForm 
		           | el módulo general AccessManagement.';
		           |es_CO = 'Ha ocurrido un error en el procedimiento OnCreateAccessValueForm 
		           | el módulo general AccessManagement.';
		           |tr = 'AccessManagement genel modülünde 
		           |OnCreateAccessValueForm prosedüründe bir hata oluştu.';
		           |it = 'Si è verificato un errore nella procedura OnCreateAccessValueForm
		           |del modulo comune AccessManagement.';
		           |de = 'In der Prozedur OnCreateAccessValueForm des
		           |allgemeinen Moduls AccessManagement ist ein Fehler aufgetreten.'");
	
	If TypeOf(CreateNewAccessValue) <> Type("Boolean") Then
		Try
			CreateNewAccessValue = NOT ValueIsFilled(Form.Object.Ref);
		Except
			ErrorInformation = ErrorInfo();
			Raise ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Параметр CreateNewAccessValue не указан, а автоматическое заполнение
				           |из реквизита формы ""Object.Ref"" недоступно по причине:
				           |%1'; 
				           |en = 'The CreateNewAccessValue parameter is not specified and automatic filling
				           |from the Object.Ref form attribute is not available due to:
				           |%1'; 
				           |pl = 'Parametr CreateNewAccessValue nie jest określony, a automatyczne wypełnienie
				           | z rekwizytów formy Object.Ref niedostępne z powodu:
				           |%1';
				           |es_ES = 'El parámetro CreateNewAccessValue no se ha indicado, y el relleno automático
				           |del requisito del formulario Object.Ref no estña disponible a causa de: 
				           |%1';
				           |es_CO = 'El parámetro CreateNewAccessValue no se ha indicado, y el relleno automático
				           |del requisito del formulario Object.Ref no estña disponible a causa de: 
				           |%1';
				           |tr = 'CreateNewAccessValue parametresi belirtilmedi ve Object.Ref formu
				           | özelliğinden şu nedenle otomatik doldurma yapılmıyor:
				           |%1';
				           |it = 'Il parametro CreateNewAccessValue non è indicato e compilato automaticamente
				           |dall''attributo di modulo Object.Ref, non disponibile a causa di:
				           |%1';
				           |de = 'Der Parameter CreateNewAccessValue ist nicht angegeben, und das automatische Ausfüllen
				           |aus den Formulardetails ""Object.Ref"" ist aus diesem Grund nicht möglich:
				           |%1'"), BriefErrorDescription(ErrorInformation));
		EndTry;
	EndIf;
	
	If TypeOf(ValueType) <> Type("Type") Then
		Try
			AccessValueType = TypeOf(Form.Object.Ref);
		Except
			ErrorInformation = ErrorInfo();
			Raise ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Параметр ValueType не указан, а автоматическое заполнение
				           |из реквизита формы ""Object.Ref"" недоступно по причине:
				           |%1'; 
				           |en = 'The ValueType parameter is not specified and automatic filling
				           |from the Object.Ref form attribute is not available due to:
				           |%1'; 
				           |pl = 'Parametr ValueType nie jest określony, a automatyczne wypełnienie
				           | z rekwizytów formy Object.Ref niedostępne z powodu:
				           |%1';
				           |es_ES = 'El parámetro ValueType no se ha indicado, y el relleno automático
				           |del requisito del formulario Object.Ref no estña disponible a causa de: 
				           |%1';
				           |es_CO = 'El parámetro ValueType no se ha indicado, y el relleno automático
				           |del requisito del formulario Object.Ref no estña disponible a causa de: 
				           |%1';
				           |tr = 'ValueType parametresi belirtilmedi ve Object.Ref formu
				           |özelliğinden şu nedenle otomatik doldurma yapılamıyor:
				           |%1';
				           |it = 'Il parametro ValueType non è indicato e compilato automaticamente
				           |dall''attributo di modulo Object.Ref, non disponibile a causa di:
				           |%1';
				           |de = 'Der Parameter ValueType ist nicht angegeben, und das automatische Ausfüllen
				           |aus den Formulardetails ""Object.Ref"" ist aus diesem Grund nicht möglich:
				           |%1'"), BriefErrorDescription(ErrorInformation));
		EndTry;
	Else
		AccessValueType = ValueType;
	EndIf;
	
	If Items = Undefined Then
		FormItems = New Array;
		FormItems.Add("AccessGroup");
		
	ElsIf TypeOf(Items) <> Type("Array") Then
		FormItems = New Array;
		FormItems.Add(Items);
	EndIf;
	
	GroupsProperties = AccessValueGroupsProperties(AccessValueType, ErrorTitle);
	
	If Attribute = Undefined Then
		Try
			AccessValuesGroup = Form.Object.AccessGroup;
		Except
			ErrorInformation = ErrorInfo();
			Raise ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Параметр Attribute не указан, а автоматическое заполнение
				           |из реквизита формы ""Object.AccessGroup"" недоступно по причине:
				           |%1'; 
				           |en = 'Attribute parameter is not specified and automatic filling
				           |from the Object.AccessGroup form attribute is not available due to:
				           |%1'; 
				           |pl = 'Parametr Rekwizyt nie jest określony, a automatyczne wypełnienie
				           | z rekwizytów formy Object.AccessGroup niedostępne z powodu:
				           |%1';
				           |es_ES = 'El parámetro de atributo no se ha indicado, y el relleno automático
				           |del requisito del formulario Object.Ref no está disponible a causa de: 
				           |%1';
				           |es_CO = 'El parámetro de atributo no se ha indicado, y el relleno automático
				           |del requisito del formulario Object.Ref no está disponible a causa de: 
				           |%1';
				           |tr = 'Özellik parametresi belirtilmedi ve Object.AccessGroup formu
				           |özelliğinden şu nedenle otomatik doldurma yapılamıyor:
				           |%1';
				           |it = 'Il parametro attributo non è indicato e compilato automaticamente
				           |dall''attributo di modulo Object.AccessGroup, non disponibile a causa di:
				           |%1';
				           |de = 'Der Parameter Attribute ist nicht angegeben, und das automatische Ausfüllen
				           |aus den Formulardetails ""Object.AccessGroup"" ist aus diesem Grund nicht möglich:
				           |%1'"), BriefErrorDescription(ErrorInformation));
		EndTry;
	Else
		PointPosition = StrFind(Attribute, ".");
		If PointPosition = 0 Then
			Try
				AccessValuesGroup = Form[Attribute];
			Except
				ErrorInformation = ErrorInfo();
				Raise ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Не удалось получить значение реквизита формы ""%1"", указанного параметре Реквизит по причине:
					           |%2'; 
					           |en = 'Cannot get an attribute value of the ""%1"" form specified in the Attribute parameter due to:
					           |%2'; 
					           |pl = 'Nie udało się uzyskać wartość rekwizytów formy ""%1"", określonego parametru Attribute z powodu:
					           |%2';
					           |es_ES = 'No se ha podido recibir un valor del requisito del formulario ""%1"" indicado en el parámetro Requisito a causa de: 
					           |%2';
					           |es_CO = 'No se ha podido recibir un valor del requisito del formulario ""%1"" indicado en el parámetro Requisito a causa de: 
					           |%2';
					           |tr = 'Özellik parametresinde belirtilen form özelliğinin değeri ""%1"" aşağıdaki nedenle alınamadı: 
					           |%2';
					           |it = 'Impossibile ottenere un valore di attributo del modulo ""%1"" indicato nel parametro Attributo a causa di:
					           |%2';
					           |de = 'Es war nicht möglich, den Wert des Formularattributs ""%1"" zu erhalten, der durch den Parameter Attribut angegeben wurde, aus dem Grund:
					           |%2'"), Attribute, BriefErrorDescription(ErrorInformation));
			EndTry;
		Else
			Try
				AccessValuesGroup = Form[Left(Attribute, PointPosition - 1)][Mid(Attribute, PointPosition + 1)];
			Except
				ErrorInformation = ErrorInfo();
				Raise ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Не удалось получить значение реквизита формы ""%1"", указанного параметре Реквизит по причине:
					           |%2'; 
					           |en = 'Cannot get an attribute value of the ""%1"" form specified in the Attribute parameter due to:
					           |%2'; 
					           |pl = 'Nie udało się uzyskać wartość rekwizytów formy ""%1"", określonego parametru Attribute z powodu:
					           |%2';
					           |es_ES = 'No se ha podido recibir un valor del requisito del formulario ""%1"" indicado en el parámetro Requisito a causa de: 
					           |%2';
					           |es_CO = 'No se ha podido recibir un valor del requisito del formulario ""%1"" indicado en el parámetro Requisito a causa de: 
					           |%2';
					           |tr = 'Özellik parametresinde belirtilen form özelliğinin değeri ""%1"" aşağıdaki nedenle alınamadı: 
					           |%2';
					           |it = 'Impossibile ottenere un valore di attributo del modulo ""%1"" indicato nel parametro Attributo a causa di:
					           |%2';
					           |de = 'Es war nicht möglich, den Wert des Formularattributs ""%1"" zu erhalten, der durch den Parameter Attribut angegeben wurde, aus dem Grund:
					           |%2'"), Attribute, BriefErrorDescription(ErrorInformation));
			EndTry;
		EndIf;
	EndIf;
	
	If TypeOf(AccessValuesGroup) <> GroupsProperties.Type Then
		Raise ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Для значений доступа типа ""%1""
			           |используются вид доступа ""%2"" с типом значений ""%3"",
			           |заданным в переопределяемом модуле.
			           |Но этот тип не совпадает с типом ""%4"" в форме значения
			           |доступа у реквизита AccessGroup.'; 
			           |en = 'The ""%2"" access kind with the ""%3"" value
			           |type specified in the overridable module is used for access values of the ""%1"" type
			           |. 
			           |This type does not match the ""%4"" type in the access value
			           |form of the AccessGroup attribute.'; 
			           |pl = 'Dla wartości dostępu typu ""%1""
			           |są używane rodzaj dostępu ""%2"" typ wartości ""%3"",
			           |określonej w zmiennym module.
			           |Ale ten typ nie zgadza się z typem ""%4"" w formie znaczenia
			           |dostępu w rekwizytach AccessGroup.';
			           |es_ES = 'Para los valores de acceso del tipo ""%1""
			           |está utilizado el tipo de acceso ""%2"" con el tipo de valores ""%3""
			           |especificado en el módulo variable.
			           |Pero este tipo no coincide con el tipo ""%4"" en el formulario del valor
			           |de acceso en el atributo AccessGroup.';
			           |es_CO = 'Para los valores de acceso del tipo ""%1""
			           |está utilizado el tipo de acceso ""%2"" con el tipo de valores ""%3""
			           |especificado en el módulo variable.
			           |Pero este tipo no coincide con el tipo ""%4"" en el formulario del valor
			           |de acceso en el atributo AccessGroup.';
			           |tr = '""%1"" Tür erişim türünün erişim 
			           |değerleri için ""%2"", geçersiz kılma modülünde belirtilen "
" değerleriyle kullanılır. 
			           |%4Ancak bu tür, ErişimGrubu özniteliğinde erişim değeri formundaki%3"" türüyle 
			           |eşleşmiyor.';
			           |it = 'Il tipo di accesso ""%2"" con tipo
			           |di valore ""%3"" indicato nel modulo Overridable è utilizzato per i valori di accesso del tipo ""%1""
			           |. 
			           |Questo tipo non corrisponde al tipo ""%4"" nel modulo
			           |del valore di accesso dell''attributo AccessGroup.';
			           |de = 'Für Zugriffswerte vom Typ ""%1""
			           |wird die Zugriffsart ""%2"" mit dem im neu definierten Modul angegebenen Werttyp ""%3""
			           |verwendet.
			           |Dieser Typ stimmt jedoch nicht mit dem Typ ""%4"" in Form eines Zugriffs
			           |wertes beim Attribut AccessGroup überein.'"),
			String(AccessValueType),
			String(GroupsProperties.AccessKind),
			String(GroupsProperties.Type),
			String(TypeOf(AccessValuesGroup)));
	EndIf;
	
	If NOT LimitAccessAtRecordLevel()
	 OR NOT AccessManagementInternal.AccessKindUsed(GroupsProperties.AccessKind) Then
		
		For each Item In FormItems Do
			Form.Items[Item].Visible = False;
		EndDo;
		Return;
	EndIf;
	
	If Users.IsFullUser( , , False) Then
		Return;
	EndIf;
	
	If Not AccessRight("Update", Metadata.FindByType(AccessValueType)) Then
		Form.ReadOnly = True;
		Return;
	EndIf;
	
	ValuesGroupsForChange =
		AccessValuesGroupsAllowingAccessValuesChange(AccessValueType);
	
	If ValuesGroupsForChange.Count() = 0
	   AND CreateNewAccessValue Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Для добавления требуются разрешенные ""%1"".'; en = 'Allowed %1 are required to add items.'; pl = 'Do dodania wymagane są dopuszczalne ""%1"".';es_ES = 'Permitidos ""%1"" se requieren para añadir.';es_CO = 'Permitidos ""%1"" se requieren para añadir.';tr = 'Eklemek için izin verilen ""%1"" gereklidir.';it = 'Permessi %1 sono richiesti per aggiungere elementi.';de = 'Zulässige ""%1"" sind zum Hinzufügen erforderlich.'"),
			Metadata.FindByType(GroupsProperties.Type).Presentation());
	EndIf;
	
	If ValuesGroupsForChange.Count() = 0
	 OR NOT CreateNewAccessValue
	   AND ValuesGroupsForChange.Find(AccessValuesGroup) = Undefined Then
		
		Form.ReadOnly = True;
		Return;
	EndIf;
	
	If CreateNewAccessValue
	   AND NOT ValueIsFilled(AccessValuesGroup)
	   AND ValuesGroupsForChange.Count() = 1 Then
		
		If Attribute = Undefined Then
			Form.Object.AccessGroup = ValuesGroupsForChange[0];
		Else
			PointPosition = StrFind(Attribute, ".");
			If PointPosition = 0 Then
				Form[Attribute] = ValuesGroupsForChange[0];
			Else
				Form[Left(Attribute, PointPosition - 1)][Mid(Attribute, PointPosition + 1)] = ValuesGroupsForChange[0];
			EndIf;
		EndIf;
	EndIf;
	
	NewChoiceParameter = New ChoiceParameter(
		"Filter.Ref", New FixedArray(ValuesGroupsForChange));
	
	ChoiceParameters = New Array;
	ChoiceParameters.Add(NewChoiceParameter);
	
	For each Item In FormItems Do
		Form.Items[Item].ChoiceParameters = New FixedArray(ChoiceParameters);
	EndDo;
	
EndProcedure

// Returns an array of access value groups allowing to change access values.
//
// Supported only when a single access value group is selected.
//
// Parameters:
//  AccessValuesType - Type - a type of access value reference.
//  ReturnAll - Boolean - if True, when no restrictions are set, an array of all groups will be 
//                       returned instead of Undefined.
//
// Returns:
//  Undefined - access values can be changed in all access value groups.
//  Array - an array of found access value groups.
//
Function AccessValuesGroupsAllowingAccessValuesChange(AccessValuesType, ReturnAll = False) Export
	
	ErrorTitle =
		NStr("ru = 'Ошибка в процедуре AccessValuesGroupsAllowingAccessValuesChange
		           |общего модуля AccessManagement.'; 
		           |en = 'An error occurred in the AccessValuesGroupsAllowingAccessValuesChange procedure
		           |of the AccessManagement common module.'; 
		           |pl = 'Wystąpił błąd w procedurze AccessValuesGroupsAllowingAccessValuesChange
		           |modułu wspólnego AccessManagement.';
		           |es_ES = 'Ha ocurrido un error en el procedimiento AccessValueGroupsAllowingAccessValuesChange 
		           |del módulo común AccessManagement.';
		           |es_CO = 'Ha ocurrido un error en el procedimiento AccessValueGroupsAllowingAccessValuesChange 
		           |del módulo común AccessManagement.';
		           |tr = 'AccessManagement ortak modülünün AccessValuesGroupsAllowingAccessValuesChange prosedüründe
		           |bir hata oluştu.';
		           |it = 'Si è verificato un errore nella procedura AccessValuesGroupsAllowingAccessValuesChange 
		           |del modulo comune AccessManagement.';
		           |de = 'In der Prozedur AccessValuesGroupsAllowingAccessValuesChange zulassen
		           |des allgemeinen Moduls AccessManagement ist ein Fehler aufgetreten.'");
	
	GroupsProperties = AccessValueGroupsProperties(AccessValuesType, ErrorTitle);
	
	If Not AccessRight("Read", Metadata.FindByType(GroupsProperties.Type)) Then
		Return New Array;
	EndIf;
	
	If NOT LimitAccessAtRecordLevel()
	 OR NOT AccessManagementInternal.AccessKindUsed(GroupsProperties.AccessKind)
	 OR Users.IsFullUser( , , False) Then
		
		If ReturnAll Then
			Query = New Query;
			Query.Text =
			"SELECT ALLOWED
			|	AccessValuesGroups.Ref AS Ref
			|FROM
			|	&AccessValueGroupsTable AS AccessValuesGroups";
			Query.Text = StrReplace(
				Query.Text, "&AccessValueGroupsTable", GroupsProperties.Table);
			
			Return Query.Execute().Unload().UnloadColumn("Ref");
		EndIf;
		
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("AccessValuesType",  GroupsProperties.ValueTypeBlankRef);
	
	Query.SetParameter("AccessValuesID",
		Common.MetadataObjectID(AccessValuesType));
	
	Query.Text =
	"SELECT
	|	AccessGroups.Ref
	|INTO UserAccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.AccessGroupsTables AS AccessGroupsTables
	|			WHERE
	|				AccessGroupsTables.Table = &AccessValuesID
	|				AND AccessGroupsTables.AccessGroup = AccessGroups.Ref
	|				AND AccessGroupsTables.Update = TRUE)
	|	AND TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|					INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|					ON
	|						UserGroupCompositions.Used
	|							AND UserGroupCompositions.User = &CurrentUser
	|							AND AccessGroupsUsers.User = UserGroupCompositions.UsersGroup
	|							AND AccessGroupsUsers.Ref = AccessGroups.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccessValuesGroups.Ref AS Ref
	|INTO ValueGroups
	|FROM
	|	&AccessValueGroupsTable AS AccessValuesGroups
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				UserAccessGroups AS UserAccessGroups
	|					INNER JOIN InformationRegister.DefaultAccessGroupsValues AS DefaultValues
	|					ON
	|						DefaultValues.AccessGroup = UserAccessGroups.Ref
	|							AND DefaultValues.AccessValuesType = &AccessValuesType
	|					LEFT JOIN InformationRegister.AccessGroupsValues AS Values
	|					ON
	|						Values.AccessGroup = UserAccessGroups.Ref
	|							AND Values.AccessValue = AccessValuesGroups.Ref
	|			WHERE
	|				ISNULL(Values.ValueAllowed, DefaultValues.AllAllowed))";
	Query.Text = StrReplace(Query.Text, "&AccessValueGroupsTable", GroupsProperties.Table);
	Query.TempTablesManager = New TempTablesManager;
	
	SetPrivilegedMode(True);
	Query.Execute();
	SetPrivilegedMode(False);
	
	Query.Text =
	"SELECT ALLOWED
	|	AccessValuesGroups.Ref AS Ref
	|FROM
	|	&AccessValueGroupsTable AS AccessValuesGroups
	|		INNER JOIN ValueGroups AS ValueGroups
	|		ON AccessValuesGroups.Ref = ValueGroups.Ref";
	
	Query.Text = StrReplace(
		Query.Text, "&AccessValueGroupsTable", GroupsProperties.Table);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Sets the condition WHERE of the dynamic list to permanent filters based on the allowed access 
// values of the specified types within all access groups.
// This helps to speed up opening of the dynamic list.
// If the total number of allowed values is over 100, the filter is not set.
//
// For the procedure to operate, a dynamic list must have a main table, an arbitrary query, and it 
// must support a conversion of this kind:
//   QuerySchema - New QuerySchema;
//   QuerySchema.SetQueryText(List.QueryText);
//   List.QueryText = QuerySchema.GetQueryText();
// If you cannot fulfill this condition, add the filters yourself using the AllowedDynamicListValues 
// function as in this procedure.
//
// Parameters:
//  List - DynamicList - a dynamic list that requires setting of filters.
//  FiltersDetails - Map - with the following properties:
//    * Key - String - a field name of the main table of the dynamic list, which requires setting 
//                          the <Field> value IN (&AllowedValues).
//    * Value - Type - a type of access values to be included in the &AllowedValues parameter.
//                          
//               - Array - an array of above listed types.
//
Procedure SetDynamicListFilters(List, FiltersDetails) Export
	
	If Not LimitAccessAtRecordLevel()
	 Or AccessManagementInternal.LimitAccessAtRecordLevelUniversally()
	 Or Users.IsFullUser(,, False) Then
		Return;
	EndIf;
	
	If TypeOf(List) <> Type("DynamicList") Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Ошибка вызова процедуры SetDynamicListFilters общего модуля AccessManagement.
			           |Значение параметра List ""%1"" не является динамическим списком.'; 
			           |en = 'An error occurred when calling the SetDynamicListFilters procedure
			           |of the AccessManagement common module. Value ""%1"" of the List parameter is not a dynamic list.'; 
			           |pl = 'Wywołanie procedury nie powiodło się SetDynamicListFilters wspólnego modułu AccessManagement.
			           |Znaczenie parametru Lista ""%1"" nie jest listą dynamiczną.';
			           |es_ES = 'Error de llamar el procedimiento SetDynamicListFilters del módulo común AccessManagement.
			           |El valor del parámetro Lista ""%1"" no es lista dinámica.';
			           |es_CO = 'Error de llamar el procedimiento SetDynamicListFilters del módulo común AccessManagement.
			           |El valor del parámetro Lista ""%1"" no es lista dinámica.';
			           |tr = 'AccessManagement genel modülün SetDynamicListFilters prosedürünün çağrı hatası.
			           |Liste ""%1"" parametresinin değeri dinamik bir liste değildir.';
			           |it = 'Si è verificato un errore durante la chiamata della procedura SetDynamicListFilters 
			           |del modulo comune AccessManagement. Il valore ""%1"" del parametro Elenco non è un elenco dinamico.';
			           |de = 'Beim Aufruf der Prozedur SetDynamicListFilters
			           |des gemeinsamen Moduls AccessManagement ist ein Fehler aufgetreten. Der Wert ""%1"" des List-Parameters ist keine dynamische Liste.'"), String(List));
	EndIf;
	
	If Not ValueIsFilled(List.MainTable) Then
		Raise
			NStr("ru = 'Ошибка вызова процедуры SetDynamicListFilters общего модуля AccessManagement.
			           |У переданного динамического списка не указана основная таблица.'; 
			           |en = 'An error occurred when calling the SetDynamicListFilters procedure of the AccessManagement common module.
			           |Main table of the passed dynamic list is not specified.'; 
			           |pl = 'Wywołanie procedury nie powiodło się SetDynamicListFilters wspólnego modułu AccessManagement.
			           |Przeniesiona lista dynamiczna nie ma głównej tabeli.';
			           |es_ES = 'Error de llamar el procedimiento SetDynamicListFilters del módulo común AccessManagement.
			           |Para la lista dinámica no está indicada una tabla principal.';
			           |es_CO = 'Error de llamar el procedimiento SetDynamicListFilters del módulo común AccessManagement.
			           |Para la lista dinámica no está indicada una tabla principal.';
			           |tr = 'AccessManagement genel modülün SetDynamicListFilters prosedürünün çağrı hatası.
			           |Sunulan dinamik listesinin ana tablosu belirtilmedi.';
			           |it = 'Si è verificato un errore durante la chiamata della procedura SetDynamicListFilters del modulo comune AccessManagement.
			           |Non è indicata la tabella principale dell''elenco dinamico trasmesso.';
			           |de = 'Fehler beim Aufruf der Prozedur SetDynamicListFilters des Moduls AccessManagement.
			           |Die übertragene dynamische Liste hat keine Haupttabelle.'");
	EndIf;
	
	If Not List.CustomQuery Then
		Raise
			NStr("ru = 'Ошибка вызова процедуры SetDynamicListFilters общего модуля AccessManagement.
			           |У переданного динамического списка не установлен флажок ""Произвольный запрос"".'; 
			           |en = 'An error occurred when calling the SetDynamicListFilters procedure of the AccessManagement common module.
			           |The dynamic list passed to the procedure does not have the ""Custom query"" check box selected.'; 
			           |pl = 'Wywołanie procedury nie powiodło się SetDynamicListFilters wspólnego modułu AccessManagement.
			           |Pole wyboru ""Zapytanie losowe"" nie jest wybrane dla przesłanej listy dynamicznej.';
			           |es_ES = 'Error de llamar el procedimiento SetDynamicListFilters del módulo común AccessManagement.
			           |La lista dinámica pasada al procedimiento no tiene seleccionada la casilla de verificación ""Consulta personalizada"".';
			           |es_CO = 'Error de llamar el procedimiento SetDynamicListFilters del módulo común AccessManagement.
			           |La lista dinámica pasada al procedimiento no tiene seleccionada la casilla de verificación ""Consulta personalizada"".';
			           |tr = 'AccessManagement genel modülün SetDynamicListFilters prosedürünün çağrı hatası.
			           |Sunulan dinamik listesinin ""Serbest talep"" onay kutusu belirlenmedi.';
			           |it = 'Si è verificato un errore durante la chiamata della procedura SetDynamicListFilters del modulo comune AccessManagement.
			           |L''elenco dinamico trasmesso alla procedura non presenta la casella di controllo ""Query personalizzata"" selezionata.';
			           |de = 'Beim Aufruf der SetDynamicListFilters-Prozedur des gemeinsamen Moduls AccessManagement ist ein Fehler aufgetreten.
			           |In der an die Prozedur übergebenen dynamischen Liste ist das Kontrollkästchen ""Benutzerdefinierte Abfrage"" nicht aktiviert.'");
	EndIf;
	
	QuerySchema = New QuerySchema;
	QuerySchema.SetQueryText(List.QueryText);
	Parameters = New Map;
	
	For Each FilterDetails In FiltersDetails Do
		FieldName = FilterDetails.Key;
		Values = AccessManagementInternal.AllowedDynamicListValues(
			List.MainTable, FilterDetails.Value);
		If Values = Undefined Then
			Continue;
		EndIf;
		
		Sources = QuerySchema.QueryBatch[0].Operators[0].Sources;
		Alias = "";
		For Each Source In Sources Do
			If Source.Source.TableName = List.MainTable Then
				Alias = Source.Source.Alias;
				Break;
			EndIf;
		EndDo;
		If Not ValueIsFilled(Alias) Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка вызова процедуры SetDynamicListFilters общего модуля AccessManagement.
				           |У переданного динамического списка не удалось найти псевдоним основной таблицы
				           |""%1"".'; 
				           |en = 'An error occurred when calling the SetDynamicListFilters procedure of the AccessManagement common module.
				           |Cannot find the alias of the ""%1"" main table
				           |in the dynamic list passed to the procedure.'; 
				           |pl = 'Wywołanie procedury nie powiodło się SetDynamicListFilters wspólnego modułu AccessManagement.
				           |Przesłana lista dynamiczna nie może znaleźć aliasu głównej tabeli
				           |""%1"".';
				           |es_ES = 'Error de llamar el procedimiento SetDynamicListFilters del módulo común AccessManagement.
				           |Para la lista dinámica no se ha podido encontrar un alias de la tabla principal
				           |""%1"".';
				           |es_CO = 'Error de llamar el procedimiento SetDynamicListFilters del módulo común AccessManagement.
				           |Para la lista dinámica no se ha podido encontrar un alias de la tabla principal
				           |""%1"".';
				           |tr = 'AccessManagement genel modülün SetDynamicListFilters prosedürünün çağrı hatası.
				           |Sunulan dinamik listesinin ana tablosunun takma adı 
				           |""%1"" bulunamadı.';
				           |it = 'Si è verificato un errore durante la chiamata della procedura SetDynamicListFilters del modulo comune AccessManagement.
				           |Impossibile trovare gli pseudonimi della tabella principale ""%1""
				           |nell''elenco dinamico trasmesso alla procedura.';
				           |de = 'Beim Aufruf der Prozedur SetDynamicListFilters des gemeinsamen Moduls AccessManagement ist ein Fehler aufgetreten.
				           |Der Alias der ""%1"" Haupttabelle
				           |in der an die Prozedur übergebenen dynamischen Liste kann nicht gefunden werden.'"), List.MainTable);
		EndIf;
		Filter = QuerySchema.QueryBatch[0].Operators[0].Filter;
		ParameterName = "AllowedFieldValues" + FieldName;
		Parameters.Insert(ParameterName, Values);
		
		Condition = Alias + "." + FieldName + " IN (&" + ParameterName + ")";
		Filter.Add(Condition);
	EndDo;
	
	List.QueryText = QuerySchema.GetQueryText();
	
	For Each KeyAndValue In Parameters Do
		UpdateDataCompositionParameterValue(List, KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
EndProcedure

// Returns an array of allowed values of the specified types within all access groups.
// Used in the SetDynamicListFilters procedure to speed up the opening of dynamic lists.
// 
// Parameters:
//  Table - String - a full name of the metadata object, for example, Document.PurchaseInvoice.
//  ValueType - Type - a type of access values whose allowed values are to be returned.
//               - Array - an array of above listed types.
//
// Returns:
//  Undefined - if the number of allowed values exceeds 100.
//  Array - references of allowed values of the specified types.
//
Function AllowedDynamicListValues(Table, ValuesType) Export
	
	If Not LimitAccessAtRecordLevel()
	 Or Users.IsFullUser( , , False) Then
		Return Undefined;
	EndIf;
	
	Return AccessManagementInternal.AllowedDynamicListValues(Table, ValuesType);
	
EndFunction

// Returns access rights to metadata objects of reference type by specified IDs.
//
// Parameters:
//  IDs - Array - values of the CatalogRef.MetadataObjectsIDs, reference type metadata objects, for 
//                            which rights are to be returned.
//
// Returns:
//  Map - with fields:
//    * Key - CatalogRef.MetadataObjectIDs - ID of the type;
//    * Value - Structure - with the following properties:
//                   * Key - String - an access right name (Read, Update, or Insert).
//                   * Value - Boolean - if True, there is the right, otherwise, there is not.
//
Function RightsByIDs(IDs = Undefined) Export
	
	IDsMetadataObjects =
		Catalogs.MetadataObjectIDs.MetadataObjectsByIDs(IDs);
	
	RightsByIDs = New Map;
	For Each IDMetadataObject In IDsMetadataObjects Do
		MetadataObject = IDMetadataObject.Value;
		Rights = New Structure;
		Rights.Insert("Read",     AccessRight("Read",     MetadataObject));
		Rights.Insert("Update",  AccessRight("Update",  MetadataObject));
		Rights.Insert("Insert", AccessRight("Insert", MetadataObject));
		RightsByIDs.Insert(IDMetadataObject.Key, Rights);
	EndDo;
	
	Return RightsByIDs;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for access value set management.

// Checks whether an access value set filling procedure is available for a metadata object.
// 
// Parameters:
//  Ref - AnyRef - a reference to any object.
//
// Returns:
//  Boolean - if True, you can fill in access value sets.
//
Function CanFillAccessValuesSets(Ref) Export
	
	ObjectType = Type(Common.ObjectKindByRef(Ref) + "Object." + Ref.Metadata().Name);
	
	SetsFilled = AccessManagementInternalCached.ObjectsTypesInSubscriptionsToEvents(
		"WriteAccessValuesSets
		|WriteDependentAccessValuesSets").Get(ObjectType) <> Undefined;
	
	Return SetsFilled;
	
EndFunction

// Returns a blank table to be filled and passed to the HasRole function and to 
// FillAccessValuesSets(Table) procedures defined by an applied developer.
//
// Returns:
//  ValueTable - a table with the following columns:
//    * SetNumber - Number - (optional if there is only one set),
//    * AccessKind - String - optional, except for special ReadRight and UpdateRight.
//    * AccessValue - Undefined, CatalogRef - or other (required),
//    * Read - Boolean - (optional if a set is used for all rights) it is set for a single row in the set, 
//    * Change - Boolean - (optional if a set is used for all rights) it is set for a single row in the set.
//
Function AccessValuesSetsTable() Export
	
	SetPrivilegedMode(True);
	
	Table = New ValueTable;
	Table.Columns.Add("SetNumber",     New TypeDescription("Number", New NumberQualifiers(4, 0, AllowedSign.Nonnegative)));
	Table.Columns.Add("AccessKind",      New TypeDescription("String", , New StringQualifiers(20)));
	Table.Columns.Add("AccessValue", Metadata.DefinedTypes.AccessValue.Type);
	Table.Columns.Add("Read",          New TypeDescription("Boolean"));
	Table.Columns.Add("Update",       New TypeDescription("Boolean"));
	// Service field cannot be filled in or changed manually (it is filled in automatically).
	Table.Columns.Add("Clarification",       New TypeDescription("CatalogRef.MetadataObjectIDs"));
	
	Return Table;
	
EndFunction

// Fills the access value sets for the passed Object value by calling the FillAccessValuesSets 
// procedure defined in the module of this object and returns them in the Table parameter.
// 
//
// Objects are to be included in the subscription to the WriteAccessValuesSets or 
// WriteDependentAccessValuesSets event.
//
// In the object modules, there must be a handler procedure the parameters are being passed to
//  Table - ValueTable - returned by the AccessValuesSetsTable function.
//
// The following is an example of a handler procedure for copying to object modules.
//
//// See AccessManagement.FillAccessValuesSets. 
//Procedure FillAccessValuesSets(Table) Export
//	
//	// Restriction logic:
//	// Reading: Company.
//	// Changes: Company And Employee responsible.
//	
//	// Reading: set No1.
//	String = Table.Add();
//	String.SetNumber = 1;
//	String.Read = True;
//	String.AccessValue = Company;
//	
//	// Change: set No2.
//	String = Table.Add();
//	String.SetNumber = 2;
//	String.Change = True;
//	String.AccessValue = Company;
//	
//	String = Table.Add();
//	String.SetNumber = 2;
//	String.AccessValue = EmployeeResponsible;
//	
//EndProcedure
//
// Parameters:
//  Object - CatalogObject, DocumentObject, CatalogRef, DocumentRef - a reference or a reference 
//            object (catalog item, document, business process, task, chart of characteristic types, 
//            etc.), for which you want to fill in access value sets.
//
//  Table - ValueTable, Undefined - returns prepared sets of access values in this parameter.
//             See description of the columns in the AccessManagement.AccessValuesSetsTable function.
//            If Undefined is passed, a new table of access value sets will be created and populated.
//
//  SubordinateObjectRef - AnyRef - used to fill in access value sets of the owner object for the 
//            specified subordinate object.
//            For details see AccessManagementOverridable.OnFillAccessRightsDependencies. 
//
Procedure FillAccessValuesSets(Val Object, Table, Val SubordinateObjectRef = Undefined) Export
	
	SetPrivilegedMode(True);
	
	// If a reference is passed, an object is received.
	// The object is not changed but used to call the FillAccessValuesSets() method.
	Object = ?(Object = Object.Ref, Object.GetObject(), Object);
	ObjectRef = Object.Ref;
	ValueTypeObject = TypeOf(Object);
	
	SetsFilled = AccessManagementInternalCached.ObjectsTypesInSubscriptionsToEvents(
		"WriteAccessValuesSets
		|WriteDependentAccessValuesSets").Get(ValueTypeObject) <> Undefined;
	
	If NOT SetsFilled Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Неверные параметры.
			           |Тип объекта ""%1""
			           |не найден ни в одной из подписок на события
			           |""Записать наборы значений доступа"",
			           |""Записать зависимые наборы значений доступа"".'; 
			           |en = 'Incorrect parameters.
			           |Object type ""%1""
			           |is not found in event subscriptions
			           |""Write access value sets"",
			           |""Write dependent access value sets"".'; 
			           |pl = 'Niepoprawne parametry.
			           |Typ obiektu ""%1""
			           |nie występuje w przypadku subskrypcji wydarzeń
			           |""Zapisz zestawy wartości dostępu"",
			           |""Zapisz zależne zestawy wartości dostępu"".';
			           |es_ES = 'Parámetros incorrectos.
			           |Tipo de objeto ""%1""
			           |se ha encontrado en no suscripción a eventos
			           |""Grabar los conjuntos del valor de acceso"",
			           |""Grabar los conjuntos del valor de acceso dependiente"".';
			           |es_CO = 'Parámetros incorrectos.
			           |Tipo de objeto ""%1""
			           |se ha encontrado en no suscripción a eventos
			           |""Grabar los conjuntos del valor de acceso"",
			           |""Grabar los conjuntos del valor de acceso dependiente"".';
			           |tr = 'Yanlış parametreler. 
			           |""Erişim değeri kümeleri yaz"", 
			           |""Bağımlı erişim değer kümeleri yaz"" 
			           |olaylarına hiçbir abonelik olmadan 
			           |nesne türü ""%1"" bulunur.';
			           |it = 'Parametri errati.
			           |Il tipo di oggetto ""%1""
			           |non è stato trovato nelle registrazioni dell''ebento
			           |""Registrare set di valori di accesso"",
			           |""Registrare i set di valori di accesso dipendenti"".';
			           |de = 'Falsche Parameter. Der
			           |Objekttyp ""%1""
			           |befindet sich in keinem Abonnement für Ereignisse
			           |""Schreibe Zugriffssätze"",
			           |""Schreibe abhängige Zugriffswertsätze"".'"),
			ValueTypeObject);
	EndIf;
	
	Table = ?(TypeOf(Table) = Type("ValueTable"), Table, AccessValuesSetsTable());
	Try
		Object.FillAccessValuesSets(Table);
	Except
		ErrorInformation = ErrorInfo();
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1 ""%2""
			           |не сформировал набор значений доступа по причине:
			           |%3'; 
			           |en = '%1 ""%2""
			           |has not generated an access value set due to:
			           |%3'; 
			           |pl = '%1 ""%2""
			           |nie utworzył zestaw wartości dostępu z powodu:
			           |%3';
			           |es_ES = '%1 ""%2""
			           |no ha generado un conjunto de valores de acceso a causa de:
			           |%3';
			           |es_CO = '%1 ""%2""
			           |no ha generado un conjunto de valores de acceso a causa de:
			           |%3';
			           |tr = '%1""%2""
			           | aşağıdaki nedenle erişim değerlerinin kümesini oluşturmadı: 
			           |%3';
			           |it = '%1 ""%2""
			           |non ha generato un insieme di valore di accesso a causa di:
			           |%3';
			           |de = '%1 ""%2""
			           |hat aus folgenden Gründen keine Zugriffswerte generiert:
			           |%3'"),
			TypeOf(ObjectRef),
			Object,
			DetailErrorDescription(ErrorInformation));
	EndTry;
	
	If Table.Count() = 0 Then
		// If you disable this condition, the scheduled job, which fills data for access restriction 
		// purposes, will loop.
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1 ""%2""
			           |сформировал пустой набор значений доступа.'; 
			           |en = '%1 ""%2""
			           |generated a blank access value set.'; 
			           |pl = '%1 ""%2""
			           |utworzył pusty zestaw wartości dostępu.';
			           |es_ES = '%1 ""%2""
			           |ha generado un conjunto vacío de datos de valores de acceso.';
			           |es_CO = '%1 ""%2""
			           |ha generado un conjunto vacío de datos de valores de acceso.';
			           |tr = '%1""%2""
			           | boş erişim değerleri kümesini oluşturdu.';
			           |it = '%1 ""%2""
			           |ha generato un set di valori di accesso vuoto.';
			           |de = '%1 ""%2""
			           |hat einen leeren Satz von Zugriffswerten generiert.'"),
			TypeOf(ObjectRef),
			Object);
	EndIf;
	
	SpecifyAccessValuesSets(ObjectRef, Table);
	
	If SubordinateObjectRef = Undefined Then
		Return;
	EndIf;
	
	// Adding sets for checking Read and Update rights of a leading owner object when generating 
	// dependent value sets in procedures prepared by the applied developer.
	// 
	//
	// No action is required when filling the final set (even if it includes dependent sets) as the 
	// rights check is embedded in the logic of the Object access kind in standard templates.
	
	// Adding a blank set to set all rights check boxes and arrange set rows.
	AddAccessValuesSets(Table, AccessValuesSetsTable());
	
	// Preparing object sets for some rights.
	ReadingSets     = AccessValuesSetsTable();
	ChangeSets  = AccessValuesSetsTable();
	For each Row In Table Do
		If Row.Read Then
			NewRow = ReadingSets.Add();
			NewRow.SetNumber     = Row.SetNumber + 1;
			NewRow.AccessKind      = Row.AccessKind;
			NewRow.AccessValue = Row.AccessValue;
			NewRow.Clarification       = Row.Clarification;
		EndIf;
		If Row.Update Then
			NewRow = ChangeSets.Add();
			NewRow.SetNumber     = (Row.SetNumber + 1)*2;
			NewRow.AccessKind      = Row.AccessKind;
			NewRow.AccessValue = Row.AccessValue;
			NewRow.Clarification       = Row.Clarification;
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AccessRightsDependencies AS AccessRightsDependencies
	|WHERE
	|	AccessRightsDependencies.SubordinateTable = &SubordinateTable
	|	AND AccessRightsDependencies.LeadingTableType = &LeadingTableType";
	
	Query.SetParameter("SubordinateTable",
		SubordinateObjectRef.Metadata().FullName());
	
	TypesArray = New Array;
	TypesArray.Add(TypeOf(ObjectRef));
	TypesDetails = New TypeDescription(TypesArray);
	Query.SetParameter("LeadingTableType", TypesDetails.AdjustValue(Undefined));
	
	RightsDependencies = Query.Execute().Unload();
	Table.Clear();
	
	ID = Common.MetadataObjectID(TypeOf(ObjectRef));
	
	If RightsDependencies.Count() = 0 Then
		
		// Adding sets by a standard rule.
		
		// Checking the Read right of the leading set owner object when checking the Read right of a 
		// subordinate object.
		Row = Table.Add();
		Row.SetNumber     = 1;
		Row.AccessKind      = "ReadRight";
		Row.AccessValue = ID;
		Row.Read          = True;
		
		// Checking the Update right of the leading set owner object while checking Insert, Update, and 
		// Delete rights of the subordinate object.
		Row = Table.Add();
		Row.SetNumber     = 2;
		Row.AccessKind      = "EditRight";
		Row.AccessValue = ID;
		Row.Update       = True;
		
		// Marking the rights that require checking the read right restriction sets for the leading owner object.
		ReadingSets.FillValues(True, "Read");
		// Marking the rights that require checking the update right restriction sets for the leading owner object.
		ChangeSets.FillValues(True, "Update");
		
		AddAccessValuesSets(ReadingSets, ChangeSets);
		AddAccessValuesSets(Table, ReadingSets, True);
	Else
		// Adding sets by a nonstandard rule: check the read rights instead of update rights.
		
		// Checking the Read right of the leading set owner object when checking the Read right of a 
		// subordinate object.
		Row = Table.Add();
		Row.SetNumber     = 1;
		Row.AccessKind      = "ReadRight";
		Row.AccessValue = ID;
		Row.Read          = True;
		Row.Update       = True;
		
		// Marking the rights that require checking the read right restriction sets for the leading owner object.
		ReadingSets.FillValues(True, "Read");
		ReadingSets.FillValues(True, "Update");
		AddAccessValuesSets(Table, ReadingSets, True);
	EndIf;
	
EndProcedure

// Adds an access value set table to another access value set table, either by logical addition or 
// by logical multiplication.
//
// The result is returned in the Destination parameter.
//
// Parameters:
//  Destination - ValueTable - with columns identical to the table returned by the AccessValuesSetsTable function.
//  Source - ValueTable - with columns identical to the table returned by the AccessValuesSetsTable function.
//
//  Multiplication - Boolean - determines a method to logically join sets of destination and source.
//  Simplify - Boolean - determines whether the sets must be simplified after addition.
//
Procedure AddAccessValuesSets(Destination, Val Source, Val Multiplication = False, Val Simplify = False) Export
	
	If Source.Count() = 0 AND Destination.Count() = 0 Then
		Return;
		
	ElsIf Multiplication AND ( Source.Count() = 0 OR  Destination.Count() = 0 ) Then
		Destination.Clear();
		Source.Clear();
		Return;
	EndIf;
	
	If Destination.Count() = 0 Then
		Value = Destination;
		Destination = Source;
		Source = Value;
	EndIf;
	
	If Simplify Then
		
		// Identifying duplicate sets and duplicate rows in sets for a specific right upon addition or 
		// multiplication.
		//
		// Duplicates occur due to unbracketing rules implemented in logical expressions:
		//  Both for sets for a specific right and sets for different rights:
		//     X AND X = X,
		//     X OR X = X, where X is a set of argument strings.
		//  Only for sets for a specific right:
		//     (a AND b AND c) OR (a AND b), where a,b,c are argument strings of sets.
		// Based on these rules, duplicate rows in sets and duplicate sets can be deleted.
		
		If Multiplication Then
			MultiplySetsAndSimplify(Destination, Source);
		Else // Insert
			AddSetsAndSimplify(Destination, Source);
		EndIf;
	Else
		
		If Multiplication Then
			MultiplySets(Destination, Source);
		Else // Insert
			AddSets(Destination, Source);
		EndIf;
	EndIf;
	
EndProcedure

// Updates object access value sets if they are changed.
// The sets are updated both in the tabular section (if used) and in the AccessValuesSets 
// information register.
//
// Parameters:
//  RefOrObject - Arbitrary - a reference or an object, for which access value sets are populated.
//  IBUpdate - Boolean - if True, it is necessary to write data without doing unnecessary redundant 
//                             actions with the data.
//                             See InfobaseUpdate.WriteData. 
//
Procedure UpdateAccessValuesSets(ReferenceOrObject, IBUpdate = False) Export
	
	AccessManagementInternal.UpdateAccessValuesSets(ReferenceOrObject,, IBUpdate);
	
EndProcedure

// FillAccessValuesSetsOfTabularSections* subscription handler for the BeforeWrite event fills 
// access values of the AccessValuesSets object tabular section when the #ByValuesSets template is 
// used to restrict access to the object.
//  The AccessManagement subsystem can be used when
// the specified subscription does not exist if the sets are not applied for the specified purpose.
//
// Parameters:
//  Source - CatalogObject,
//                    DocumentObject,
//                    ChartOfCharacteristicTypesObject,
//                    ChartOfAccountsObject,
//                    ChartOfCalculationTypesObject,
//                    BusinessProcessObject,
//                    TaskObject,
//                    ExchangePlanObject - a data object passed to the BeforeWrite event subscription.
//
//  Cancel - Boolean - a parameter passed to the BeforeWrite event subscription.
//
//  WriteMode - Boolean - a parameter passed to the BeforeWrite event subscription when the type of 
//                    the Source parameter is DocumentObject.
//
//  PostingMode - Boolean - parameter passed to the BeforeWrite event subscription when the Source 
//                    parameter type is DocumentObject.
//
Procedure FillAccessValuesSetsForTabularSections(Source, Cancel = Undefined, WriteMode = Undefined, PostingMode = Undefined) Export
	
	// Check of the DataExchange.Import is ignored only when the WriteAccessValuesSets property is set.
	// 
	// In this case, when recording the leading object for its correct RLS operations, a program 
	// recording of the subordinate object is performed to update the AccessValuesSets service tabular section.
	If Source.DataExchange.Load
	   AND NOT Source.AdditionalProperties.Property("WriteAccessValuesSets") Then
		Return;
	EndIf;
	
	If StandardSubsystemsServer.IsMetadataObjectID(Source) Then
		Return;
	EndIf;
	
	If NOT (  PrivilegedMode()
	         AND Source.AdditionalProperties.Property(
	             "AccessValuesSetsOfTabularSectionAreFilled")) Then
		
		Table = AccessManagementInternal.GetAccessValuesSetsOfTabularSection(Source);
		AccessManagementInternal.PrepareAccessValuesSetsForWrite(Undefined, Table, False);
		Source.AccessValuesSets.Load(Table);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used in the overridable module.

// Returns a structure used for easier description of supplied profiles.
//
// Returns:
//  Structure - with the following properties:
//   * Name - String - PredefinedDataName is used to link the supplied data to the predefined item.
//                       
//   * ID - String - a UUID string of the supplied profile used to search in the database.
//                       
//                       To receive the ID, create a profile in 1C:Enterprise mode and get the 
//                       reference UUID. Do not specify IDs received using an arbitrary method as 
//                       this may violate the uniqueness of the references.
//   * Description - String - a supplied profile description.
//   * Details - String - description of the supplied profile.
//   * Roles - Array - names of the supplied profile roles.
//   * Assignment - Array - types of user references and external user authorization objects.
//                        If blank, then the assignment is for users.
//                       They must be within the content of the defined User type.
//   * AccessKinds - ValuesList - with the following properties:
//                     * Value - String - an access kind name specified in the 
//                         AccessManagementOverridable overridable module in the OnFillAccessKinds procedure.
//                     * Presentation - String - the following values are allowed: "AllDeniedByDefault" (or a blank string),
//                        "AllAllowedByDefault," and "PresetAccessKind."
//
//   * AccessValues - ValuesList - with the following properties:
//                     * Value - String - an access kind name specified in the AccessKinds parameter.
//                     * Presentation - String - a predefined item name, for example,
//                         "Catalog.UserGroups.AllUsers".
//
// Example:
// 
//	// User profile.
//	ProfileDetails = AccessManagement.NewAccessGroupProfileDetails(),
//	ProfileDetails.Name = User;
//	ProfileDetails.ID = 09e56dbf-90a0-11de-862c-001d600d9ad2;
//	ProfileDetails.Description = NStr("en = 'User'", Metadata.DefaultLanguage.LanguageCode);
//	// Redefining an assignment.
//	CommonClientServer.SupplementArray(ProfileDetails.Assignment,
//		Metadata.DefinedTypes.ExternalUser.Type.Types());
//	ProfileDetails.Details =
//		NStr("en = 'Common actions allowed for most users.
//		           |As a rule, these are rights to view the infobase data.'",
//			Metadata.DefaultLanguage.LanguageCode);
//	// Using 1C: Enterprise.
//	ProfileDetails.Roles.Add("StartThinClient");
//	ProfileDetails.Roles.Add("OutputToPrinterFileClipboard");
//	ProfileDetails.Roles.Add("SaveUserData");
//	// ...
//	// Using the application.
//	ProfileDetails.Roles.Add("BasicSSLRights");
//	ProfileDetails.Roles.Add("ViewApplicationChangesLog");
//	ProfileDetails.Roles.Add("EditCurrentUser");
//	// ...
//	// Using master data.
//	ProfileDetails.Roles.Add("ReadBasicMasterData";
//	ProfileDetails.Roles.Add("ReadCommonBasicMasterData");
//	// ...
//	// Standard features.
//	ProfileDetails.Roles.Add("AddEditPersonalReportsOptions");
//	ProfileDetails.Roles.Add("ViewLinkedDocuments");
//	// ...
//	// Basic profile features.
//	ProfileDetails.Roles.Add("AddEditNotes");
//	ProfileDetails.Roles.Add("AddEditReminders");
//	ProfileDetails.Roles.Add("AddEditJobs");
//	ProfileDetails.Roles.Add("EditCompleteTasks");
//	// ...
//	// Profile access restriction kinds.
//	ProfileDetails.AccessKinds.Add("Companies");
//	ProfileDetails.AccessKinds.Add("Users", "Preset");
//	ProfileDetails.AccessKinds.Add("BusinessTransactions", "Preset");
//	ProfileDetails.AccessValues.Add("BusinessTransactions",
//		"Enumeration.BusinessTransactions.CashIssueToAdvanceHolder");
//	// ...
//	ProfilesDetails.Add(ProfileDetails);
//
Function NewAccessGroupProfileDescription() Export
	
	NewDetails = New Structure;
	NewDetails.Insert("Name",             "");
	NewDetails.Insert("ID",   "");
	NewDetails.Insert("Description",    "");
	NewDetails.Insert("Details",        "");
	NewDetails.Insert("Roles",            New Array);
	NewDetails.Insert("Purpose",      New Array);
	NewDetails.Insert("AccessKinds",     New ValueList);
	NewDetails.Insert("AccessValues", New ValueList);
	
	Return NewDetails;
	
EndFunction

// Adds additional types to the OnFillAccessKinds procedure of the AccessManagementOverridable 
// common module.
//
// Parameters:
//  AccessKind - ValuesTableRow - added to the AccessKinds parameter.
//  ValuesType - Type - an additional type of access values.
//  ValuesGroupsType - Type - an additional access value group type, it can match the type of the 
//                           previously specified value groups for the same access kind.
//  MultipleValuesGroups - Boolean - True if you can specify multiple value groups for an additional 
//                           access value type (the AccessGroups tabular section exists).
// 
Procedure AddExtraAccessKindTypes(AccessKind, ValuesType,
		ValuesGroupsType = Undefined, MultipleValuesGroups = False) Export
	
	AdditionalTypes = AccessKind.AdditionalTypes;
	
	If AdditionalTypes.Columns.Count() = 0 Then
		AdditionalTypes.Columns.Add("ValuesType",            New TypeDescription("Type"));
		AdditionalTypes.Columns.Add("ValuesGroupsType",       New TypeDescription("Type"));
		AdditionalTypes.Columns.Add("MultipleValuesGroups", New TypeDescription("Boolean"));
	EndIf;
	
	NewRow = AdditionalTypes.Add();
	NewRow.ValuesType            = ValuesType;
	NewRow.ValuesGroupsType       = ValuesGroupsType;
	NewRow.MultipleValuesGroups = MultipleValuesGroups;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used for infobase update.

// Replaces roles in profiles, except for supplied profiles updated automatically.
// It is called from the exclusive update handler.
//
// Parameters:
//  RolesToReplace - Map - with values:
//    * Key - String - a name of the role to be replaced, for example, ReadBasicMasterData. If the 
//                          role is deleted, add the prefix "?" to the name, for example, "? ReadBasicMasterData".
//
//    * Value - Array - role names to replace the specified one (blank array to delete the specified role).
//
Procedure ReplaceRolesInProfiles(RolesToReplace) Export
	
	RolesRefsToReplace = New Map;
	RolesToReplaceArray = New Array;
	
	For Each KeyAndValue In RolesToReplace Do
		If StrStartsWith(KeyAndValue.Key, "? ") Then
			RoleRefs = Catalogs.MetadataObjectIDs.DeletedMetadataObjectID(
				"Role." + TrimAll(Mid(KeyAndValue.Key, 3)));
		Else
			RoleRefs = New Array;
			RoleRefs.Add(Common.MetadataObjectID("Role." + KeyAndValue.Key));
		EndIf;
		For Each RoleRef In RoleRefs Do
			RolesToReplaceArray.Add(RoleRef);
			NewRoles = New Array;
			RolesRefsToReplace.Insert(RoleRef, NewRoles);
			For Each NewRole In KeyAndValue.Value Do
				NewRoles.Add(Common.MetadataObjectID("Role." + NewRole));
			EndDo;
		EndDo;
	EndDo;
	
	// Find profiles that use the roles being replaced.
	Query = New Query;
	Query.SetParameter("RolesToReplaceArray", RolesToReplaceArray);
	Query.SetParameter("BlankID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	Query.Text =
	"SELECT
	|	ProfileRoles.Ref AS Profile,
	|	ProfileRoles.Role AS Role
	|FROM
	|	Catalog.AccessGroupProfiles AS Profiles
	|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfileRoles
	|		ON (ProfileRoles.Ref = Profiles.Ref)
	|			AND (ProfileRoles.Role IN (&RolesToReplaceArray))
	|			AND (Profiles.SuppliedDataID = &BlankID
	|				OR Profiles.SuppliedProfileChanged)
	|TOTALS BY
	|	Profile";
	
	ProfilesTree = Query.Execute().Unload(QueryResultIteration.ByGroups);
	
	For Each ProfileRow In ProfilesTree.Rows Do
		
		ProfileObject = ProfileRow.Profile.GetObject();
		ProfileRoles = ProfileObject.Roles;
		
		For Each RoleRow In ProfileRow.Rows Do
			
			// Deleting the role being replaced from the profile.
			Filter = New Structure("Role", RoleRow.Role);
			FoundRows = ProfileRoles.FindRows(Filter);
			For Each FoundRow In FoundRows Do
				ProfileRoles.Delete(FoundRow);
			EndDo;
			
			// Adding new roles to the profile instead of the role being replaced.
			RolesToAdd = RolesRefsToReplace.Get(RoleRow.Role);
			
			For Each RoleToAdd In RolesToAdd Do
				Filter = New Structure;
				Filter.Insert("Role", RoleToAdd);
				If ProfileRoles.FindRows(Filter).Count() = 0 Then
					NewRow = ProfileRoles.Add();
					NewRow.Role = RoleToAdd;
				EndIf;
			EndDo;
		EndDo;
		
		InfobaseUpdate.WriteData(ProfileObject);
		
	EndDo;
	
	Catalogs.AccessGroupProfiles.UpdateAuxiliaryProfilesData(
		ProfilesTree.Rows.UnloadColumn("Profile"));
	
EndProcedure

// Returns a reference to a supplied profile by ID.
//
// Parameters:
//  ID - String - a name or UUID of a supplied profile as specified in the OnFillAccessKinds 
//                  procedure of the AccessManagementOverridable common module.
//
// Returns:
//  CatalogRef.AccessGroupsProfiles - if the supplied profile is found in the catalog.
//  Undefined - if the supplied profile is not found in the catalog.
//
Function SuppliedProfileByID(ID) Export
	
	Return Catalogs.AccessGroupProfiles.SuppliedProfileByID(ID);
	
EndFunction

// Returns a blank table to be filled in and passed to the ReplaceRightsInObjectsRightsSettings 
// procedure.
//
// Returns:
//  ValueTable - a table with the following columns:
//    * OwnersType - Ref - a blank reference of the right owner type from the type description.
//                      RightsSettingsOwner, for example, a blank reference of the FilesFolders catalog.
//    * PreviousName - String - a previous right name.
//    * NewName - String - a new right name.
//
Function TableOfRightsReplacementInObjectsRightsSettings() Export
	
	Dimensions = Metadata.InformationRegisters.ObjectsRightsSettings.Dimensions;
	
	Table = New ValueTable;
	Table.Columns.Add("OwnersType", Dimensions.Object.Type);
	Table.Columns.Add("OldName",     Dimensions.UserRight.Type);
	Table.Columns.Add("NewName",      Dimensions.UserRight.Type);
	
	Return Table;
	
EndFunction

// Replaces rights used in the object rights settings.
// After the replacement, auxiliary data is updated in the ObjectsRightsSettings information 
// register, so the procedure is to be called only once to avoid performance decrease.
// 
// 
// Parameters:
//  RenamedTable - ValueTable - a table with the following columns:
//    * OwnersType - Ref - a blank reference of the right owner type from the type description.
//                      RightsSettingsOwner, for example, a blank reference of the FilesFolders catalog.
//    * PreviousName - String - a previous right name related to the specified owner type.
//    * NewName - String - a new right name related to the specified owner type.
//                      If a blank string is specified, the old right setting will be deleted.
//                      If two new names are mapped to the previous name, the old right setting will 
//                      be duplicated.
//  
Procedure ReplaceRightsInObjectsRightsSettings(RenamedTable) Export
	
	Query = New Query;
	Query.Parameters.Insert("RenamedTable", RenamedTable);
	Query.Text =
	"SELECT
	|	RenamedTable.OwnersType,
	|	RenamedTable.OldName,
	|	RenamedTable.NewName
	|INTO RenamedTable
	|FROM
	|	&RenamedTable AS RenamedTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.UserRight,
	|	MAX(RightsSettings.RightIsProhibited) AS RightIsProhibited,
	|	MAX(RightsSettings.InheritanceIsAllowed) AS InheritanceIsAllowed,
	|	MAX(RightsSettings.SettingsOrder) AS SettingsOrder
	|INTO OldRightsSettings
	|FROM
	|	InformationRegister.ObjectsRightsSettings AS RightsSettings
	|
	|GROUP BY
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.UserRight
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OldRightsSettings.Object,
	|	OldRightsSettings.User,
	|	RenamedTable.OldName,
	|	RenamedTable.NewName,
	|	OldRightsSettings.RightIsProhibited,
	|	OldRightsSettings.InheritanceIsAllowed,
	|	OldRightsSettings.SettingsOrder
	|INTO RightsSettings
	|FROM
	|	OldRightsSettings AS OldRightsSettings
	|		INNER JOIN RenamedTable AS RenamedTable
	|		ON (VALUETYPE(OldRightsSettings.Object) = VALUETYPE(RenamedTable.OwnersType))
	|			AND OldRightsSettings.UserRight = RenamedTable.OldName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsSettings.NewName
	|FROM
	|	RightsSettings AS RightsSettings
	|
	|GROUP BY
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.NewName
	|
	|HAVING
	|	RightsSettings.NewName <> """" AND
	|	COUNT(RightsSettings.NewName) > 1
	|
	|UNION
	|
	|SELECT
	|	RightsSettings.NewName
	|FROM
	|	RightsSettings AS RightsSettings
	|		LEFT JOIN OldRightsSettings AS OldRightsSettings
	|		ON RightsSettings.Object = OldRightsSettings.Object
	|			AND RightsSettings.User = OldRightsSettings.User
	|			AND RightsSettings.NewName = OldRightsSettings.UserRight
	|WHERE
	|	NOT OldRightsSettings.UserRight IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.OldName,
	|	RightsSettings.NewName,
	|	RightsSettings.RightIsProhibited,
	|	RightsSettings.InheritanceIsAllowed,
	|	RightsSettings.SettingsOrder
	|FROM
	|	RightsSettings AS RightsSettings";
	
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.ObjectsRightsSettings");
	
	BeginTransaction();
	Try
		Lock.Lock();
		QueryResults = Query.ExecuteBatch();
		
		RepeatedNewNames = QueryResults[QueryResults.Count()-2].Unload();
		
		If RepeatedNewNames.Count() > 0 Then
			RepeatedNewRightsNames = "";
			For each Row In RepeatedNewNames Do
				RepeatedNewRightsNames = RepeatedNewRightsNames
					+ ?(ValueIsFilled(RepeatedNewRightsNames), "," + Chars.LF, "")
					+ Row.NewName;
			EndDo;
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка в параметрах процедуры ReplaceRightsInObjectsRightsSettings
				           |общего модуля AccessManagement.
				           |
				           |После обновления будут повторяться настройки следующих новых имен прав:
				           |%1.'; 
				           |en = 'An error occurred in parameters of the ReplaceRightsInObjectsRightsSettings procedure
				           |of the AccessManagement common module.
				           |
				           |After update, settings of the following new right names will be repeated:
				           |%1.'; 
				           |pl = 'Błąd w parametrach procedury ReplaceRightsInObjectsRightsSettings
				           |wspólnego modułu AccessManagement.
				           |
				           |Po aktualizacji będą powtarzały się ustawienia następnych nowych imion praw:
				           |%1.';
				           |es_ES = 'Error en los parámetros del procedimiento ReplaceRightsInObjectsRightsSettings
				           |del módulo común AccessManagement.
				           |
				           |Al actualizar se repetirán los ajustes de los siguientes nombres de derechos nuevos:
				           |%1.';
				           |es_CO = 'Error en los parámetros del procedimiento ReplaceRightsInObjectsRightsSettings
				           |del módulo común AccessManagement.
				           |
				           |Al actualizar se repetirán los ajustes de los siguientes nombres de derechos nuevos:
				           |%1.';
				           |tr = 'AccessManagement genel modülünün
				           | ReplaceRightsInObjectsRightsSettings işlem parametrelerinde bir hata oluştu.
				           |
				           |Güncellemeden sonra hakların aşağıdaki yeni isimlerin ayarları tekrarlanacaktır:
				           |%1.';
				           |it = 'Si è verificato un errore nei parametri della procedura ReplaceRightsInObjectsRightsSettings
				           |del modulo comune AccessManagement.
				           |
				           |Dopo l''aggiornamento, le impostazioni dei seguenti nuovi nomi dei diritti saranno ripetuti:
				           |%1.';
				           |de = 'Fehler in den Parametern der Prozedur ReplaceRightsInObjectsRightsSettings des
				           |allgemeinen Moduls AccessManagement.
				           |
				           |Nach dem Update werden die Einstellungen für die folgenden neuen Rechte wiederholt:
				           |%1.'"),
				RepeatedNewRightsNames);
		EndIf;
		
		ReplacementTable = QueryResults[QueryResults.Count()-1].Unload();
		
		RecordSet = InformationRegisters.ObjectsRightsSettings.CreateRecordSet();
		
		IBUpdate = InfobaseUpdate.InfobaseUpdateInProgress()
		           Or InfobaseUpdate.IsCallFromUpdateHandler();
		
		For each Row In ReplacementTable Do
			RecordSet.Filter.Object.Set(Row.Object);
			RecordSet.Filter.User.Set(Row.User);
			RecordSet.Filter.Right.Set(Row.OldName);
			RecordSet.Read();
			If RecordSet.Count() > 0 Then
				RecordSet.Clear();
				If IBUpdate Then
					InfobaseUpdate.WriteData(RecordSet);
				Else
					RecordSet.Write();
				EndIf;
			EndIf;
		EndDo;
		
		NewRecord = RecordSet.Add();
		For each Row In ReplacementTable Do
			If Row.NewName = "" Then
				Continue;
			EndIf;
			RecordSet.Filter.Object.Set(Row.Object);
			RecordSet.Filter.User.Set(Row.User);
			RecordSet.Filter.Right.Set(Row.NewName);
			FillPropertyValues(NewRecord, Row);
			NewRecord.UserRight = Row.NewName;
			If IBUpdate Then
				InfobaseUpdate.WriteData(RecordSet);
			Else
				RecordSet.Write();
			EndIf;
		EndDo;
		
		InformationRegisters.ObjectsRightsSettings.UpdateAuxiliaryRegisterData();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used to update internal data.

// Updates a role list of infobase users by their current access groups.
//  Infobase users with the FullAccess role are skipped.
// 
// Parameters:
//  UsersArray - Array, Undefined, Type - an array of elements.
//     CatalogRef.Users or CatalogRef.ExternalUsers.
//     If Undefined, update all user roles.
//     If Type = Catalog.ExternalUsers, all external user roles are updated, otherwise, all user 
//     roles are updated.
//
//  ServiceUserPassword - String - a password for authorization in the service manager.
//
Procedure UpdateUserRoles(Val UsersArray = Undefined, Val ServiceUserPassword = Undefined) Export
	
	AccessManagementInternal.UpdateUserRoles(UsersArray, ServiceUserPassword);
	
EndProcedure

// Updates the AccessGroupsValues and DefaultAccessGroupsValues registers that are filled in on the 
// basis of the access group settings and access kind use.
//
Procedure UpdateAllowedValuesOnChangeAccessKindsUsage() Export
	
	InformationRegisters.AccessGroupsValues.UpdateRegisterData();
	
EndProcedure

// Sequentially fills and partially updates data required by the AccessManagement subsystem in the 
// access restriction mode at the record level.
// 
// Fills in access value sets when the access restriction mode is enabled at the record level.
//  The sets are filled in by portions during each run, until all access value sets are filled in.
// 
//
// When the restriction access mode at the record level is disabled, the access value sets filled in 
// earlier are removed upon rewriting the objects, not immediately.
//
// Updates secondary data (access value groups and additional fields in the existing access value 
// sets) regardless of the access restriction mode at the record level.
// Disables the scheduled job after all updates are completed and data is filled.
//
// The progress information is written to the event log.
// The procedure can be called programmatically, for example, when updating the infobase.
//
// Parameters:
//  DataVolume - Number - (return value) contains the number of data objects that were filled.
//                     
//
Procedure DataFillingForAccessRestriction(DataVolume = 0) Export
	
	AccessManagementInternal.DataFillingForAccessRestriction(DataVolume);
	
EndProcedure

// To speed up data batch processing in the current session (full user), it disables and enables the 
// calculation of rights when recording an object or a record set (update of access keys to objects 
// and register records, as well as the rights to access groups, users, and external users to new 
//  access keys).
//
// It is recommended to:
// - restore from XML backup,
// - import data from file,
// - mass data import when exchanging data,
// - batch object modification.
//
// Parameters:
//  Disable - Boolean - True - disables the update of access keys and enables the mode of collecting 
//                         components of tables (lists), for which access keys will be updated while 
//                         continuing update of access keys.
//                     - False - schedules update of the table access keys collected in the disable 
//                         mode and enables the standard mode of access keys update.
//
//  ScheduleUpdate - Boolean - scheduling an update when disabling and continuing.
//                            When Disable = True, determines whether to collect the table 
//                              components, for which an update will be scheduled.
//                              False is only required in the import mode from the XML backup when 
//                              all the infobase data is imported, including all service data.
//                            When Disable = False, it determines whether an update for the 
//                              collected tables are to be scheduled.
//                              False is required in the processing of an exception after a 
//                              transaction is canceled if there is an external transaction, since 
//                              any record to the database in this state will result in an error, 
//                              and besides, there is no need to schedule an update after canceling the transaction.
// Example:
//
//  Option 1. Recording an object set out of a transaction (TransactionActive() = False).
//
//	AccessManagement.DisableAccessKeysUpdate(True);
//	Try
//		// Recording a set of objects.
//		// ...
//		AccessManagement.DisableAccessKeysUpdate(False);
//	Except
//		AccessManagement.DisableAccessKeysUpdate(False);
//		//...
//		RaiseException;
//	EndTry;
//
//  Option 2. Recording an object set in the transaction (TransactionActive() = True).
//
//	AccessManagement.DisableAccessKeysUpdate(True);
//	StartTransaction();
//	Try
//		DataLock.Lock();
//		// ...
//		// Recording a set of objects.
//		// ...
//		AccessManagement.DisableAccessKeysUpdate(False);
//		CommitTransaction();
//	Except
//		CancelTransaction();
//		AccessManagement.DisableAccessKeysUpdate(False, False);
//		//...
//		RaiseException;
//	EndTry;
//
Procedure DisableAccessKeysUpdate(Disable, ScheduleUpdate = True) Export
	
	If Not Common.SeparatedDataUsageAvailable()
	 Or Not AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		Return;
	EndIf;
	
	If Disable AND Not Users.IsFullUser() Then
		ErrorText =
			NStr("ru = 'Некорректный вызов процедуры DisableAccessKeysUpdate общего модуля AccessManagement.
			           |Отключение обновления ключей доступа возможно только для полноправного пользователя или
			           |в привилегированном режиме.'; 
			           |en = 'Invalid call of the DisableAccessKeysUpdate procedure of the AccessManagement common module.
			           |Only rightful user or
			           |user in the privileged mode can disable update of access keys.'; 
			           |pl = 'Nieprawidłowe wywołanie procedury DisableAccessKeysUpdate wspólnego modułu AccessManagement.
			           |Wyłączenie aktualizacji kluczy dostępu jest możliwe tylko dla trybu pełnego użytkownika lub
			           |w trybie uprzywilejowanym.';
			           |es_ES = 'Llamada incorrecta del procedimiento DisableAccessKeysUpdate del módulo común AccessManagement.
			           |Es posible desactivar la actualización de claves de acceso solo para el usuari de derechos completos o
			           |en el modo privilegiado.';
			           |es_CO = 'Llamada incorrecta del procedimiento DisableAccessKeysUpdate del módulo común AccessManagement.
			           |Es posible desactivar la actualización de claves de acceso solo para el usuari de derechos completos o
			           |en el modo privilegiado.';
			           |tr = 'AccessManagement genel modülün DisableAccessKeysUpdate prosedürün çağrısı yanlıştır.
			           |Erişim anahtarlarının güncellenmesi yalnızca tam yetkili kullanıcı veya
			           |öncelikli modda mümkündür.';
			           |it = 'Chiamata non valida della procedura DisableAccessKeysUpdate del modulo comune AccessManagement.
			           |Solo un utente con diritti o 
			           |un utente in modalità a privilegi ampliati può disabilitare l''aggiornamento delle chiavi di accesso.';
			           |de = 'Ein falscher Aufruf der Prozedur DisableAccessKeysUpdate des allgemeinen Moduls AccessManagement.
			           |Das Deaktivieren der Aktualisierung von Zugriffsschlüsseln ist nur für einen Vollbenutzer oder im
			           |privilegierten Modus möglich.'");
		Raise ErrorText;
	EndIf;
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	DisableUpdate = SessionParameters.DIsableAccessKeysUpdate;
	Standard = Disable AND    ScheduleUpdate;
	Full      = Disable AND Not ScheduleUpdate;
	
	If DisableUpdate.Standard = Standard
	   AND DisableUpdate.Full      = Full Then
		Return;
	EndIf;
	
	DisableUpdate = New Structure(DisableUpdate);
	
	If Not Disable AND ScheduleUpdate Then
		EditedLists = DisableUpdate.EditedLists.Get();
		If EditedLists.Count() > 0 Then
			Lists = New Array;
			For Each KeyAndValue In EditedLists Do
				Lists.Add(Metadata.FindByType(KeyAndValue.Key).FullName());
			EndDo;
			PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters();
			PlanningParameters.AllowedAccessKeys = False;
			AccessManagementInternal.ScheduleAccessUpdate(Lists, PlanningParameters);
			DisableUpdate.EditedLists = New ValueStorage(New Map);
			AccessManagementInternalCached.ChangedListsCacheOnDisabledAccessKeysUpdate().Clear();
		EndIf;
	EndIf;
	
	DisableUpdate.Standard = Standard;
	DisableUpdate.Full      = Full;
	
	SessionParameters.DIsableAccessKeysUpdate = New FixedStructure(DisableUpdate);
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
EndProcedure

#Region ForCallsFromOtherSubsystems

// ServiceSubsystems.TMPAMEMObjects

// Assignment: for a universal document journal in the register (ERP).
// Used to hide a duplicate journal entry for transfer records when it is known that there will be 
// two entries at once.
//
// Checks whether there is a table restriction by the specified access kind.
//
// If for all table access kinds in at least one access group that grants rights to the specified 
// table the restriction is not configured (all values are allowed for all access kinds), there is 
// no restriction by the specified access kind. Otherwise, there is no restriction by the specified 
// access kind unless it is present in all the access groups for the specified table.
// 
// Parameters:
//  Table - Row - a full metadata object name, for example, Document.PurchaseInvoice.
//  AccessKind - String - an access kind name, for example, Companies.
//  AllAccessKinds - String - names of all access kinds used in table restrictions, for example, 
//                            Companies,PartnersGroups,Warehouses.
//
// Returns:
//  Boolean - if True, there is a table restriction by a specified access kind.
// 
Function HasTableRestrictionByAccessKind(Table, AccessKind, AllAccessKinds) Export
	
	Return AccessManagementInternal.HasTableRestrictionByAccessKind(Table,
		AccessKind, AllAccessKinds);
	
EndFunction

// End ServiceSubsystems.TMPAMEM

// Development.RightsAndAccessRestrictionsDevelopment

// Assignment: to call ASDS restrictions from the constructor.
// 
// Parameters:
//  MainTable - String - a full name of the main table of the metadata object, for example, Document.SalesOrder.
//  RestrictionText - String - a restriction text specified in the metadata object manager module to 
//    restrict users or external users.
//
// Returns:
//  Structure - with the following properties:
//   * InternalData - Structure - data to pass to the RestrictionStructure function.
//   * TablesFields - Map - with properties:
//     ** Key - Map - a name of the metadata object collection, for example, Catalogs.
//     ** Value - Map - with properties:
//       *** Key - String - a table (metadata object) name in uppercase.
//       *** Value - Structure - with the following properties:
//         **** TableExists - Boolean - False (True to fill in, if exists).
//         **** Fields - Map - with properties:
//           ***** Key - String - an attribute name in uppercase, including period-separated, for 
//                                 example, OWNER.COMPANY, GOODS.PRODUCTS.
//           ***** Value - Structure - with the following properties:
//             ****** FieldWithError - Number - 0 (for filling, if the field has an error. If 1, 
//                       then there is an error in the name of the first part of the field. If 2, 
//                       then an error is in the name of the second part of the field, i.e. after the first period).
//             ****** ErrorKind - Row - NotFound, TabularSectionWithoutField,
//                       TabularSectionAfterDot.
//             ****** Collection - Row - a blank row (for filling, if the first part of the field 
//                       exists, i.e. a field part before the first period). Options: Attributes,
//                      TabularSections, StandardAttributes, StandardTabularSections,
//                      Dimensions, Resources, Graphs, AccountingFlags, ExtDimensionAccountingFlags,
//                      AddressingAttributes, SpecialFields. Special fields are
//                      Value - for the Constant.* tables,
//                      Recorder and Period - for the Sequence.* tables,
//                      RecalculationObject, CalculationType for the CalculationRegister.<Name>.<RecalculationName> tables.
//                      Fields after the first period can be related only to the following collections: Attributes,
//                      StandardAttributes, AccountingFlags, and AddressingAttributes. You do not 
//                      need to specify a collection for these parts of the field name.
//             ****** ContainsTypes - Map - with properties:
//               ******* Key - String - a full name of the reference table in uppercase.
//               ******* Value - Structure - with the following properties:
//                 ******** TypeName - String - a type name whose presence you need to check.
//                 ******** ContainsType - Boolean - False (True for filling in, if the field of the 
//                                                         last field has a type).
//         **** Predefined - Map - with properties:
//           ***** Key - String - a predefined item name.
//           ***** Value - Structure - with the following properties:
//             ****** NameExists - Boolean - False (True to fill in, if there is a predefined item).
//
//         **** Extensions - Map - with properties:
//           ***** Key - String - a name of the third table name, for example, a tabular section name.
//           ***** Value - Structure - with the following properties:
//             ****** TableExists - Boolean - False (True to fill in, if exists).
//             ****** Fields - Map - with properties like for the main table (see above).
//
Function ParsedRestriction(MainTable, RestrictionText) Export
	
	Return AccessManagementInternal.ParsedRestriction(MainTable, RestrictionText);
	
EndFunction

// Assignment: to call ASDS restrictions from the constructor.
// 
// Parameters:
//  ParsedRestriction - Structure - returned by the ParsedRestriction function, but the TableExists, 
//     FieldWithError, ContainsType, and NameExists nested properties must be filled in the 
//     TablesFields properties before passing this parameter.
//
// Returns:
//  Structure - with the following properties:
//   * ErrorDescription - Structure - with the following properties:
//      * HasErrors - Boolean - if True, one or more errors are found.
//      * ErrorsText - String - a text of all errors.
//      * Restriction - String - a numbered text of the restriction with the <<?>> symbols.
//      * Errors - Array - with a part of description of separate errors.
//          ** Value - Structure - with the following properties:
//              *** StringNumber - Number - a line in the multiline text, in which an error was found.
//              *** PositionInString - Number - a number of the character, from which the error was 
//                                            found. It can be outside the line (line length + 1).
//              *** ErrorText - String - an error text without describing the position.
//              *** ErrorString - String - a line, in which an error with the added <<?>> was found.
//      * Addition - String - description of options of the first restriction part keywords.
//
//   * AdditionalTables - Array - with elements:
//       ** Value - Structure - with the following properties:
//           *** Table - String - a full metadata object name.
//           *** Alias - String - a table alias name.
//           *** ConnectionCondition - Structure - as in the ChangeRestriction property, but the 
//                                     nodes are: "Field", "Value", "Constant", "AND", "=".
//   * MainTableAlias - String - filled in if additional tables are specified.
//   * ReadRestriction - Structure - as in the ChangeRestriction property.
//   * ChangeRestriction - Structure - with the following properties:
//
//      ** Node - String - one of the lines "Field", "Value", "Constant",
//           "And", "Or", "Not", "=", "<>", "In" "IsNull", "Type", "ValueType", "Choice",
//           "ValueAllowed", "IsAuthorizedUser"
//           "ReadObjectAllowed", "EditObjectAllowed",
//           "ReadListAllowed", "EditListAllowed",
//           "ForAllLines", "ForOneOfLines".
//
//     Field node properties:
//       ** Name - String - a field name, for example, "Company", or "MainCompany".
//       ** Table - String - a table name of this field (or a blank row for the main table).
//       ** Alias - String - an attached table alias name (or a blank row for the main table), for 
//                        example, "SettingInformationRegister" for the "MainCompany" field.
//       ** Cast - String - a table name (if used), for example, to describe a field as:
//                       "CAST(CAST(Owner AS Catalog.Files).FileOwner AS Catalog.Companies).Ref".
//       ** Attachment - Structure - the Field node that contains the CAST nested action (with or without IsNull).
//                    - Undefined - there is no nested field.
//       ** IsNull - Structure - the Value Or Constant node, for example, to describe an expression of the following type:
//                        "IsNULL(Owner, Value(Catalog.Files.BlankRef))".
//                    - Undefined - if IsNull is not used (including when the Attachment property is filled in).
//
//     Value node properties:
//       ** Name - String - a value name, for example, "Catalog.Companies.Main",
//                                                 "Catalog.Companies.BlankRef".
//
//     Constant node properties:
//       ** Value - Boolean, Number, String, Undefined - False, True, an arbitrary integer number up 
//                       to 16 digits or an arbitrary string up to 150 characters.
//
//     Properties of the AND, OR nodes:
//       ** Arguments - Array - with the following elements:
//            *** Value - Structure - any node except for Value or Constant.
//
//     Properties of the Not node:
//       ** Argument - Structure - any node except for Value or Constant.
//
//     Properties of the =, <> nodes:
//       ** FirstArgument - Structure - the Field node.
//       ** SecondArgument - Structure - nodes Value, Constant. The Field node is only for the connection condition.
//
//     Properties of the IN node:
//       ** Sought - Structure - the Field node.
//       ** Values - Array - with the following elements:
//            *** Value - Structure - the Value or Constant nodes.
//
//     Properties of the IsNull node:
//       ** Argument - Structure - the Field node (an expression of the "<Field> IS NULL" kind).
//
//     Type node properties:
//       ** Name - String - a table name, for example, "Catalog.Companies".
//
//     ValueType node properties:
//       ** Argument - Structure - the Field node.
//
//     Case node properties:
//       ** Case - Structure - the Field node.
//                - Undefined - the conditions contain an expression, not the Value node.
//       ** When - Array - with the following elements:
//            *** Value - Structure - with the following properties:
//                  **** Condition - Structure - the Value node if the Case property is specified, 
//                                              otherwise, nodes And, Or, Not, =, <>, In (applied to the nested content).
//                  **** Value - Structure - any node, except for Case.
//       ** Else - Structure - any node, except for CASE and Value (the Field and Constant nodes can be only of the Boolean type).
//
//     Properties of the ValueAllowed, IsAuthorizedUser,
//                    ReadObjectAllowed, EditObjectAllowed,
//                    ReadListAllowed, EditListAllowed:
//       ** Field - Structure - the Field node.
//       ** Types - Array - with the following elements:
//            *** Value - String - a full table name
//       ** CheckTypesExceptSpecified - Boolean - of True, all types of the Field property, except 
//                                                 for those specified in the Types property.
//       ** ComparisonClarifications - Map - with the following properties:
//            *** Key - String - a clarified value is Undefined, Null, or BlankRef,
//                                    <a full table name>, "Number", "String", "Date", and "Boolean".
//            *** Value - String - result "False", "True".
//
//     Properties of the ForAllLines, ForOneOfLines nodes:
//       ** Argument - Structure - any node.
//
Function RestrictionStructure(ParsedRestriction) Export
	
	Return AccessManagementInternal.RestrictionStructure(ParsedRestriction);
	
EndFunction

// End Development.RightsAndAccessRestrictionsDevelopment

#EndRegion

#EndRegion

#Region Private

// Addition to the FillAccessValuesSets procedure.

// Casts a value set table to the tabular section or record set format.
//  It is executed before writing to the AccessValuesSets register or
// before writing an object with the AccessValuesSets tabular section.
//
// Parameters:
//  ObjectRef - CatalogRef.*, DocumentRef.*, ... - an object, for which sets are saved.
//  Table - InformationRegisterRecordSet.AccessValuesSets - sets that require clarification.
//
Procedure SpecifyAccessValuesSets(ObjectRef, Table)
	
	AccessKindsNames = AccessManagementInternalCached.AccessKindsProperties().ByNames;
	
	AvailableRights = AccessManagementInternalCached.RightsForObjectsRightsSettingsAvailable();
	RightsSettingsOwnersTypes = AvailableRights.ByRefsTypes;
	
	For each Row In Table Do
		
		If RightsSettingsOwnersTypes.Get(TypeOf(Row.AccessValue)) <> Undefined
		   AND NOT ValueIsFilled(Row.Clarification) Then
			
			Row.Clarification = Common.MetadataObjectID(TypeOf(ObjectRef));
		EndIf;
		
		If Row.AccessKind = "" Then
			Continue;
		EndIf;
		
		If Row.AccessKind = "ReadRight"
		 OR Row.AccessKind = "EditRight" Then
			
			If TypeOf(Row.AccessValue) <> Type("CatalogRef.MetadataObjectIDs") Then
				Row.AccessValue =
					Common.MetadataObjectID(TypeOf(Row.AccessValue));
			EndIf;
			
			If Row.AccessKind = "ReadRight" Then
				Row.Clarification = Catalogs.MetadataObjectIDs.EmptyRef();
			Else
				Row.Clarification = Row.AccessValue;
			EndIf;
		
		ElsIf AccessKindsNames.Get(Row.AccessKind) <> Undefined
		      OR Row.AccessKind = "RightsSettings" Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Объект ""%1"" сформировал набор значений доступа,
				           |содержащий известный вид доступа ""%2"", который не требуется указывать.
				           |
				           |Указывать требуется только специальные виды доступа
				           |""ReadRight"", ""UpdateRight"", если они используются.'; 
				           |en = 'Object ""%1"" has generated an access value set
				           |that contains known access kind ""%2"", which is not required.
				           |
				           |Specify only special access kinds
				           |ReadRight and UpdateRight if they are used.'; 
				           |pl = 'Obiekt ""%1"" wygenerował zestaw
				           |wartości dostępu zawierający znany typ dostępu ""%2"", który nie powinien być określony.
				           |
				           |Określ tylko specjalne rodzaje dostępu
				           |""ReadRight"", ""UpdateRight"", jeśli są używane.';
				           |es_ES = 'Conjunto de valores
				           |de acceso generado del objeto ""%1"" contiene el tipo de acceso conocido ""%2"", que no tiene que especificarse.
				           |
				           |Especificar solo los tipos
				           |de acceso especiales ""ReadingRight"", ""ChangingRight"", si se utilizan.';
				           |es_CO = 'Conjunto de valores
				           |de acceso generado del objeto ""%1"" contiene el tipo de acceso conocido ""%2"", que no tiene que especificarse.
				           |
				           |Especificar solo los tipos
				           |de acceso especiales ""ReadingRight"", ""ChangingRight"", si se utilizan.';
				           |tr = 'Nesne ""%1"", belirtilen erişim türünü "
" içeren belirlenmemiş erişim değerleri oluşturuldu. %2
				           |Kullanıldıkları zaman sadece ""HakkıOkuma"", ""HakkıDeğiştirme"" 
				           |
				           |özel erişim türlerini belirtin.';
				           |it = 'L''oggetto ""%1"" ha generato un set di valori di accesso
				           |contenente tipi di accesso conosciuti ""%2"" non richiesti.
				           |
				           |Indicare solo i tipi di accesso speciali
				           |ReadRight e UpdateRight se utilizzati.';
				           |de = 'Objekt ""%1"" generierte Zugriffswerte
				           |, die eine bekannte Zugriffsart ""%2"" enthalten, die nicht angegeben werden sollte.
				           |
				           |Spezifizieren Sie nur spezielle Zugriffsarten
				           | ""ReadRight"", ""UpdateRight"", wenn sie verwendet werden.'"),
				TypeOf(ObjectRef),
				Row.AccessKind);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Объект ""%1"" сформировал набор значений доступа,
				           |содержащий неизвестный вид доступа ""%2"".'; 
				           |en = 'Object ""%1"" has generated an access value set
				           |that contains unknown access kind ""%2"".'; 
				           |pl = 'Obiekt ""%1"" wygenerował zestaw
				           |wartości dostępu zawierający nieznany typ dostępu ""%2"".';
				           |es_ES = 'Objeto ""%1"" ha generado el conjunto de valores
				           |de acceso, que contiene el tipo de acceso desconocido ""%2"".';
				           |es_CO = 'Objeto ""%1"" ha generado el conjunto de valores
				           |de acceso, que contiene el tipo de acceso desconocido ""%2"".';
				           |tr = 'Nesne ""%1"", bilinmeyen erişim türünü içeren "
" erişim değerleri kümesini ""%2"" oluşturdu.';
				           |it = 'L''oggetto ""%1"" ha generato un set di valori di accesso
				           |contenente un tipo di accesso sconosciuto ""%2"".';
				           |de = 'Objekt ""%1"" generierte Zugriffswerte
				           |, die die unbekannte Zugriffsart ""%2"" enthalten.'"),
				TypeOf(ObjectRef),
				Row.AccessKind);
		EndIf;
		
		Row.AccessKind = "";
	EndDo;
	
EndProcedure

// For the AddAccessValuesSets procedure.

Function TableSets(Table, RightsNormalization = False)
	
	TableSets = New Map;
	
	For each Row In Table Do
		Set = TableSets.Get(Row.SetNumber);
		If Set = Undefined Then
			Set = New Structure;
			Set.Insert("Read", False);
			Set.Insert("Update", False);
			Set.Insert("Rows", New Array);
			TableSets.Insert(Row.SetNumber, Set);
		EndIf;
		If Row.Read Then
			Set.Read = True;
		EndIf;
		If Row.Update Then
			Set.Update = True;
		EndIf;
		Set.Rows.Add(Row);
	EndDo;
	
	If RightsNormalization Then
		For each SetDetails In TableSets Do
			Set = SetDetails.Value;
			
			If NOT Set.Read AND NOT Set.Update Then
				Set.Read    = True;
				Set.Update = True;
			EndIf;
		EndDo;
	EndIf;
	
	Return TableSets;
	
EndFunction

Procedure AddSets(Destination, Source)
	
	DestinationSets = TableSets(Destination);
	SourceSets = TableSets(Source);
	
	MaxSetNumber = -1;
	
	For each DestinationSetDetails In DestinationSets Do
		DestinationSet = DestinationSetDetails.Value;
		
		If NOT DestinationSet.Read AND NOT DestinationSet.Update Then
			DestinationSet.Read    = True;
			DestinationSet.Update = True;
		EndIf;
		
		For each Row In DestinationSet.Rows Do
			Row.Read    = DestinationSet.Read;
			Row.Update = DestinationSet.Update;
		EndDo;
		
		If DestinationSetDetails.Key > MaxSetNumber Then
			MaxSetNumber = DestinationSetDetails.Key;
		EndIf;
	EndDo;
	
	NewSetNumber = MaxSetNumber + 1;
	
	For each SourceSetDetails In SourceSets Do
		SourceSet = SourceSetDetails.Value;
		
		If NOT SourceSet.Read AND NOT SourceSet.Update Then
			SourceSet.Read    = True;
			SourceSet.Update = True;
		EndIf;
		
		For each SourceRow In SourceSet.Rows Do
			NewRow = Destination.Add();
			FillPropertyValues(NewRow, SourceRow);
			NewRow.SetNumber = NewSetNumber;
			NewRow.Read      = SourceSet.Read;
			NewRow.Update   = SourceSet.Update;
		EndDo;
		
		NewSetNumber = NewSetNumber + 1;
	EndDo;
	
EndProcedure

Procedure MultiplySets(Destination, Source)
	
	DestinationSets = TableSets(Destination);
	SourceSets = TableSets(Source, True);
	Table = AccessValuesSetsTable();
	
	CurrentSetNumber = 1;
	For each DestinationSetDetails In DestinationSets Do
			DestinationSet = DestinationSetDetails.Value;
		
		If NOT DestinationSet.Read AND NOT DestinationSet.Update Then
			DestinationSet.Read    = True;
			DestinationSet.Update = True;
		EndIf;
		
		For each SourceSetDetails In SourceSets Do
			SourceSet = SourceSetDetails.Value;
			
			ReadMultiplication    = DestinationSet.Read    AND SourceSet.Read;
			ChangeMultiplication = DestinationSet.Update AND SourceSet.Update;
			If NOT ReadMultiplication AND NOT ChangeMultiplication Then
				Continue;
			EndIf;
			For each DestinationRow In DestinationSet.Rows Do
				Row = Table.Add();
				FillPropertyValues(Row, DestinationRow);
				Row.SetNumber = CurrentSetNumber;
				Row.Read      = ReadMultiplication;
				Row.Update   = ChangeMultiplication;
			EndDo;
			For each SourceRow In SourceSet.Rows Do
				Row = Table.Add();
				FillPropertyValues(Row, SourceRow);
				Row.SetNumber = CurrentSetNumber;
				Row.Read      = ReadMultiplication;
				Row.Update   = ChangeMultiplication;
			EndDo;
			CurrentSetNumber = CurrentSetNumber + 1;
		EndDo;
	EndDo;
	
	Destination = Table;
	
EndProcedure

Procedure AddSetsAndSimplify(Destination, Source)
	
	DestinationSets = TableSets(Destination);
	SourceSets = TableSets(Source);
	
	ResultSets   = New Map;
	TypesCodes          = New Map;
	EnumerationsCodes   = New Map;
	SetRowsTable = New ValueTable;
	
	FillTypesCodesAndSetStringsTable(TypesCodes, EnumerationsCodes, SetRowsTable);
	
	CurrentSetNumber = 1;
	
	AddSimplifiedSetsToResult(
		ResultSets, DestinationSets, CurrentSetNumber, TypesCodes, EnumerationsCodes, SetRowsTable);
	
	AddSimplifiedSetsToResult(
		ResultSets, SourceSets, CurrentSetNumber, TypesCodes, EnumerationsCodes, SetRowsTable);
	
	FillDestinationByResultSets(Destination, ResultSets);
	
EndProcedure

Procedure MultiplySetsAndSimplify(Destination, Source)
	
	DestinationSets = TableSets(Destination);
	SourceSets = TableSets(Source, True);
	
	ResultSets   = New Map;
	TypesCodes          = New Map;
	EnumerationsCodes   = New Map;
	SetRowsTable = New ValueTable;
	
	FillTypesCodesAndSetStringsTable(TypesCodes, EnumerationsCodes, SetRowsTable);
	
	CurrentSetNumber = 1;
	
	For each DestinationSetDetails In DestinationSets Do
		DestinationSet = DestinationSetDetails.Value;
		
		If NOT DestinationSet.Read AND NOT DestinationSet.Update Then
			DestinationSet.Read    = True;
			DestinationSet.Update = True;
		EndIf;
		
		For each SourceSetDetails In SourceSets Do
			SourceSet = SourceSetDetails.Value;
			
			ReadMultiplication    = DestinationSet.Read    AND SourceSet.Read;
			ChangeMultiplication = DestinationSet.Update AND SourceSet.Update;
			If NOT ReadMultiplication AND NOT ChangeMultiplication Then
				Continue;
			EndIf;
			
			SetStrings = SetRowsTable.Copy();
			
			For each DestinationRow In DestinationSet.Rows Do
				Row = SetStrings.Add();
				Row.AccessKind      = DestinationRow.AccessKind;
				Row.AccessValue = DestinationRow.AccessValue;
				Row.Clarification       = DestinationRow.Clarification;
				FillRowID(Row, TypesCodes, EnumerationsCodes);
			EndDo;
			For each SourceRow In SourceSet.Rows Do
				Row = SetStrings.Add();
				Row.AccessKind      = SourceRow.AccessKind;
				Row.AccessValue = SourceRow.AccessValue;
				Row.Clarification       = SourceRow.Clarification;
				FillRowID(Row, TypesCodes, EnumerationsCodes);
			EndDo;
			
			SetStrings.GroupBy("RowID, AccessKind, AccessValue, Clarification");
			SetStrings.Sort("RowID");
			
			SetID = "";
			For each Row In SetStrings Do
				SetID = SetID + Row.RowID + Chars.LF;
			EndDo;
			
			ExistingSet = ResultSets.Get(SetID);
			If ExistingSet = Undefined Then
				
				SetProperties = New Structure;
				SetProperties.Insert("Read",      ReadMultiplication);
				SetProperties.Insert("Update",   ChangeMultiplication);
				SetProperties.Insert("Rows",      SetStrings);
				SetProperties.Insert("SetNumber", CurrentSetNumber);
				ResultSets.Insert(SetID, SetProperties);
				CurrentSetNumber = CurrentSetNumber + 1;
			Else
				If ReadMultiplication Then
					ExistingSet.Read = True;
				EndIf;
				If ChangeMultiplication Then
					ExistingSet.Update = True;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	FillDestinationByResultSets(Destination, ResultSets);
	
EndProcedure

Procedure FillTypesCodesAndSetStringsTable(TypesCodes, EnumerationsCodes, SetRowsTable)
	
	EnumerationsCodes = AccessManagementInternalCached.EnumerationsCodes();
	
	TypesCodes = AccessManagementInternalCached.RefsTypesCodes("DefinedType.AccessValue");
	
	TypeCodeLength = 0;
	For each KeyAndValue In TypesCodes Do
		TypeCodeLength = StrLen(KeyAndValue.Value);
		Break;
	EndDo;
	
	RowIDLength =
		20 // String of the access kind name
		+ TypeCodeLength
		+ 36 // Length of the string representation of a unique ID (access value).
		+ 36 // Length of the string representation of the unique ID (adjustment).
		+ 6; // Space for separators
	
	SetRowsTable = New ValueTable;
	SetRowsTable.Columns.Add("RowID", New TypeDescription("String", , New StringQualifiers(RowIDLength)));
	SetRowsTable.Columns.Add("AccessKind",          New TypeDescription("String", , New StringQualifiers(20)));
	SetRowsTable.Columns.Add("AccessValue",     Metadata.DefinedTypes.AccessValue.Type);
	SetRowsTable.Columns.Add("Clarification",           New TypeDescription("CatalogRef.MetadataObjectIDs"));
	
EndProcedure

Procedure FillRowID(Row, TypesCodes, EnumerationsCodes)
	
	If Row.AccessValue = Undefined Then
		AccessValueID = "";
	Else
		AccessValueID = EnumerationsCodes.Get(Row.AccessValue);
		If AccessValueID = Undefined Then
			AccessValueID = String(Row.AccessValue.UUID());
		EndIf;
	EndIf;
	
	Row.RowID = Row.AccessKind + ";"
		+ TypesCodes.Get(TypeOf(Row.AccessValue)) + ";"
		+ AccessValueID + ";"
		+ Row.Clarification.UUID() + ";";
	
EndProcedure

Procedure AddSimplifiedSetsToResult(ResultSets, SetsToAdd, CurrentSetNumber, TypesCodes, EnumerationsCodes, SetRowsTable)
	
	For each SetToAddDetails In SetsToAdd Do
		SetToAdd = SetToAddDetails.Value;
		
		If NOT SetToAdd.Read AND NOT SetToAdd.Update Then
			SetToAdd.Read    = True;
			SetToAdd.Update = True;
		EndIf;
		
		SetStrings = SetRowsTable.Copy();
		
		For each StringOfSetToAdd In SetToAdd.Rows Do
			Row = SetStrings.Add();
			Row.AccessKind      = StringOfSetToAdd.AccessKind;
			Row.AccessValue = StringOfSetToAdd.AccessValue;
			Row.Clarification       = StringOfSetToAdd.Clarification;
			FillRowID(Row, TypesCodes, EnumerationsCodes);
		EndDo;
		
		SetStrings.GroupBy("RowID, AccessKind, AccessValue, Clarification");
		SetStrings.Sort("RowID");
		
		SetID = "";
		For each Row In SetStrings Do
			SetID = SetID + Row.RowID + Chars.LF;
		EndDo;
		
		ExistingSet = ResultSets.Get(SetID);
		If ExistingSet = Undefined Then
			
			SetProperties = New Structure;
			SetProperties.Insert("Read",      SetToAdd.Read);
			SetProperties.Insert("Update",   SetToAdd.Update);
			SetProperties.Insert("Rows",      SetStrings);
			SetProperties.Insert("SetNumber", CurrentSetNumber);
			ResultSets.Insert(SetID, SetProperties);
			
			CurrentSetNumber = CurrentSetNumber + 1;
		Else
			If SetToAdd.Read Then
				ExistingSet.Read = True;
			EndIf;
			If SetToAdd.Update Then
				ExistingSet.Update = True;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Function FillDestinationByResultSets(Destination, ResultSets)
	
	Destination = AccessValuesSetsTable();
	
	For each SetDetails In ResultSets Do
		SetProperties = SetDetails.Value;
		For each Row In SetProperties.Rows Do
			NewRow = Destination.Add();
			NewRow.SetNumber     = SetProperties.SetNumber;
			NewRow.AccessKind      = Row.AccessKind;
			NewRow.AccessValue = Row.AccessValue;
			NewRow.Clarification       = Row.Clarification;
			NewRow.Read          = SetProperties.Read;
			NewRow.Update       = SetProperties.Update;
		EndDo;
	EndDo;
	
EndFunction

// For the OnCreateAccessValueForm and AccessValuesGroupsAllowingAccessValuesChange procedures.
Function AccessValueGroupsProperties(AccessValueType, ErrorTitle)
	
	SetPrivilegedMode(True);
	
	GroupsProperties = New Structure;
	
	AccessKindsProperties = AccessManagementInternalCached.AccessKindsProperties();
	AccessKindProperties = AccessKindsProperties.AccessValuesWithGroups.ByTypes.Get(AccessValueType);
	
	If AccessKindProperties = Undefined Then
		Raise ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Для значений доступа типа ""%1""
			           |не используются группы значений доступа.'; 
			           |en = 'Access value groups are not used for
			           |access values of the ""%1"" type.'; 
			           |pl = 'Dla wartości dostępu typu ""%1"" nie są używane
			           |grupy dostępu.';
			           |es_ES = 'Para los valores de acceso del tipo ""%1""
			           |los grupos del valor de acceso no se utilizan.';
			           |es_CO = 'Para los valores de acceso del tipo ""%1""
			           |los grupos del valor de acceso no se utilizan.';
			           |tr = '""%1"" tipi erişim
			           | değeri gruplarının erişim değerleri kullanılmaz.';
			           |it = 'I gruppi di valori di accesso non sono utilizzati
			           |per i valori di accesso del tipo ""%1"".';
			           |de = 'Bei den Zugriffswerten vom Typ ""%1""
			           |werden Zugriffswertegruppen nicht verwendet.'"),
			String(AccessValueType));
	EndIf;
	
	GroupsProperties.Insert("AccessKind", AccessKindProperties.Name);
	GroupsProperties.Insert("Type",        AccessKindProperties.ValuesGroupsType);
	
	GroupsProperties.Insert("Table",    Metadata.FindByType(
		AccessKindProperties.ValuesGroupsType).FullName());
	
	GroupsProperties.Insert("ValueTypeBlankRef",
		AccessManagementInternal.MetadataObjectEmptyRef(AccessValueType));
	
	Return GroupsProperties;
	
EndFunction

// For the ConfigureDynamicListFilters function.
Procedure UpdateDataCompositionParameterValue(Val ParametersOwner,
                                                    Val ParameterName,
                                                    Val ParameterValue)
	
	For each Parameter In ParametersOwner.Parameters.Items Do
		If String(Parameter.Parameter) = ParameterName Then
			
			If Parameter.Use
			   AND Parameter.Value = ParameterValue Then
				Return;
			EndIf;
			Break;
			
		EndIf;
	EndDo;
	
	ParametersOwner.Parameters.SetParameterValue(ParameterName, ParameterValue);
	
EndProcedure

// For the EnableProfileForUser and DisableProfileForUser procedures.
Procedure EnableDisableUserProfile(User, Profile, Enable)
	
	If Not AccessManagementInternal.SimplifiedAccessRightsSetupInterface() Then
		Raise
			NStr("ru = 'Данная операция возможна только для упрощенного
			           |интерфейса настройки прав доступа.'; 
			           |en = 'This operation is possible only in the simplified interface
			           |of access rights.'; 
			           |pl = 'Ta operacja jest możliwa tylko dla uproszczonego
			           | interfejsu ustawienia praw dostępu.';
			           |es_ES = 'Esta operación es posible solo para la interfaz
			           |simplificada de ajustes de derechos de acceso.';
			           |es_CO = 'Esta operación es posible solo para la interfaz
			           |simplificada de ajustes de derechos de acceso.';
			           |tr = 'Bu işlem yalnızca sadeleştirilmiş erişim hakları arayüzü
			           | için mümkündür.';
			           |it = 'Questa operazione è possibile solo nell''interfaccia semplificata
			           |dei diritti di accesso.';
			           |de = 'Diese Operation ist nur für eine vereinfachte
			           |Schnittstelle zum Festlegen von Zugriffsrechten möglich.'");
	EndIf;
	
	If Enable Then
		ProcedureOrFunctionName = "EnableProfileForUser";
	Else
		ProcedureOrFunctionName = "DisableUserProfile";
	EndIf;
	
	// Checking value types of the User parameter.
	If TypeOf(User) <> Type("CatalogRef.Users")
	   AND TypeOf(User) <> Type("CatalogRef.ExternalUsers") Then
		
		ParameterName = "User";
		ParameterValue = User;
		Types = New Array;
		Types.Add(Type("CatalogRef.Users"));
		Types.Add(Type("CatalogRef.ExternalUsers"));
		ExpectedTypes = New TypeDescription(Types);
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Недопустимое значение параметра %1 в %2.
			           |Ожидалось: %3; передано значение: %4 (тип %5).'; 
			           |en = 'Invalid value for the %1 parameter in %2. 
			           |Expected: %3, passed: %4 (type %5).'; 
			           |pl = 'Niepoprawna wartość parametru %1 w %2.
			           |Oczekiwano:%3; przekazana wartość: %4 (typ %5).';
			           |es_ES = 'Valor no admitido del parámetro %1 en %2.
			           |Se esperaba: %3; se ha transmitido el valor: %4 (tipo %5).';
			           |es_CO = 'Valor no admitido del parámetro %1 en %2.
			           |Se esperaba: %3; se ha transmitido el valor: %4 (tipo %5).';
			           |tr = '%1''deki %2 parametrenin geçersiz değeri.
			           |Beklenen %5 ; gönderilen değer %3 (%4 tür).';
			           |it = 'Valore del parametro %1 in %2 non valido.
			           |Atteso: %3; valore immesso: %4 (tipo %5).';
			           |de = 'Ungültiger Parameterwert %1 in %2.
			           |Erwartet: %3; übergebener Wert: %4(Typ %5).'"),
			ParameterName,
			ProcedureOrFunctionName,
			ExpectedTypes, 
			?(ParameterValue <> Undefined, ParameterValue, NStr("ru = 'Неопределено'; en = 'Undefined'; pl = 'Nieokreślone';es_ES = 'No definido';es_CO = 'No definido';tr = 'Tanımlanmamış';it = 'Non definito';de = 'Nicht definiert'")),
			TypeOf(ParameterValue));
	EndIf;
	
	// Checking value types of the Profile parameter.
	If TypeOf(Profile) <> Type("CatalogRef.AccessGroupProfiles")
	   AND TypeOf(Profile) <> Type("String")
	   AND TypeOf(Profile) <> Type("UUID")
	   AND Not (Not Enable AND TypeOf(Profile) = Type("Undefined")) Then
		
		ParameterName = "Profile";
		ParameterValue = Profile;
		Types = New Array;
		Types.Add(Type("CatalogRef.AccessGroupProfiles"));
		Types.Add(Type("String"));
		Types.Add(Type("UUID"));
		If Not Enable Then
			Types.Add(Type("Undefined"));
		EndIf;
		ExpectedTypes = New TypeDescription(Types);
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Недопустимое значение параметра %1 в %2.
			           |Ожидалось: %3; передано значение: %4 (тип %5).'; 
			           |en = 'Invalid value for the %1 parameter in %2. 
			           |Expected: %3, passed: %4 (type %5).'; 
			           |pl = 'Niepoprawna wartość parametru %1 w %2.
			           |Oczekiwano:%3; przekazana wartość: %4 (typ %5).';
			           |es_ES = 'Valor no admitido del parámetro %1 en %2.
			           |Se esperaba: %3; se ha transmitido el valor: %4 (tipo %5).';
			           |es_CO = 'Valor no admitido del parámetro %1 en %2.
			           |Se esperaba: %3; se ha transmitido el valor: %4 (tipo %5).';
			           |tr = '%1''deki %2 parametrenin geçersiz değeri.
			           |Beklenen %5 ; gönderilen değer %3 (%4 tür).';
			           |it = 'Valore del parametro %1 in %2 non valido.
			           |Atteso: %3; valore immesso: %4 (tipo %5).';
			           |de = 'Ungültiger Parameterwert %1 in %2.
			           |Erwartet: %3; übergebener Wert: %4(Typ %5).'"),
			ParameterName,
			ProcedureOrFunctionName,
			ExpectedTypes, 
			?(ParameterValue <> Undefined, ParameterValue, NStr("ru = 'Неопределено'; en = 'Undefined'; pl = 'Nieokreślone';es_ES = 'No definido';es_CO = 'No definido';tr = 'Tanımlanmamış';it = 'Non definito';de = 'Nicht definiert'")),
			TypeOf(ParameterValue));
	EndIf;
	
	If TypeOf(Profile) = Type("CatalogRef.AccessGroupProfiles")
	 Or TypeOf(Profile) = Type("Undefined") Then
		
		CurrentProfile = Profile;
	Else
		CurrentProfile = Catalogs.AccessGroupProfiles.SuppliedProfileByID(
			Profile, True);
	EndIf;
	
	If CurrentProfile <> Undefined Then
		ProfileProperties = Common.ObjectAttributesValues(CurrentProfile,
			"Description, AccessKinds");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	&FilterCriterion";
	Query.SetParameter("User", User);
	If CurrentProfile = Catalogs.AccessGroupProfiles.Administrator Then
		FilterCriterion = "AccessGroups.Ref = Value(Catalog.AccessGroups.Administrators)";
	Else
		FilterCriterion = "AccessGroups.User = &User";
		If Enable Or CurrentProfile <> Undefined Then
			FilterCriterion = FilterCriterion + Chars.LF + "	AND AccessGroups.Profile = &Profile";
			Query.SetParameter("Profile", CurrentProfile);
		EndIf;
	EndIf;
	Query.Text = StrReplace(Query.Text, "&FilterCriterion", FilterCriterion);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	Lock = New DataLock();
	LockItem = Lock.Add("Catalog.AccessGroups");
	LockItem.DataSource = QueryResult;
	
	BeginTransaction();
	Try
		Lock.Lock();
		Selection.Next();
		While True Do
			PersonalAccessGroup = Selection.Ref;
			If ValueIsFilled(PersonalAccessGroup) Then
				AccessGroupObject = PersonalAccessGroup.GetObject();
				AccessGroupObject.DeletionMark = False;
				
			ElsIf CurrentProfile <> Undefined Then
				// Creating a personal access group.
				AccessGroupObject = Catalogs.AccessGroups.CreateItem();
				AccessGroupObject.Parent     = Catalogs.AccessGroups.PersonalAccessGroupsParent();
				AccessGroupObject.Description = ProfileProperties.Description;
				AccessGroupObject.User = User;
				AccessGroupObject.Profile      = CurrentProfile;
				AccessGroupObject.AccessKinds.Load(AccessKindsForNewAccessGroup(ProfileProperties));
			Else
				AccessGroupObject = Undefined;
			EndIf;
			
			If PersonalAccessGroup = Catalogs.AccessGroups.Administrators Then
				UserDetails =  AccessGroupObject.Users.Find(
					User, "User");
				
				If Enable AND UserDetails = Undefined Then
					AccessGroupObject.Users.Add().User = User;
				ElsIf Not Enable AND UserDetails <> Undefined Then
					AccessGroupObject.Users.Delete(UserDetails);
				EndIf;
				
				If Not Common.DataSeparationEnabled() Then
					// Checking a blank list of infobase users in the Administrators access group.
					ErrorDescription = "";
					AccessManagementInternal.CheckAdministratorsAccessGroupForIBUser(
						AccessGroupObject.Users, ErrorDescription);
					
					If ValueIsFilled(ErrorDescription) Then
						Raise
							NStr("ru = 'Профиль Администратор должен быть хотя бы у одного пользователя,
							           |которому разрешен вход в программу.'; 
							           |en = 'At least one user that can sign in to the application
							           |must have the Administrator profile.'; 
							           |pl = 'Profil Administrator musi być przypisany chociażby do jednego użytkownika,
							           |posiadającego uprawnienia do wejścia do programu.';
							           |es_ES = 'Aunque sea un usuario debe tener el perfil Administrador,
							           |al que está permitido entrar en el programa.';
							           |es_CO = 'Aunque sea un usuario debe tener el perfil Administrador,
							           |al que está permitido entrar en el programa.';
							           |tr = 'Programa girmesine izin verilen en az bir kullanıcı, 
							           | Yönetici profiline sahip olmalıdır.';
							           |it = 'Almeno un utente che può accere all''applicazione
							           |deve avere un profilo da Amministratore.';
							           |de = 'Das Administrator-Profil muss von mindestens einem Benutzer gehalten werden,
							           |der sich am Programm anmelden darf.'");
					EndIf;
				EndIf;
			ElsIf AccessGroupObject <> Undefined Then
				AccessGroupObject.Users.Clear();
				If Enable Then
					AccessGroupObject.Users.Add().User = User;
				EndIf;
			EndIf;
			
			If AccessGroupObject <> Undefined Then
				AccessGroupObject.Write();
			EndIf;
			
			If Not Selection.Next() Then
				Break;
			EndIf;
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function AccessKindsForNewAccessGroup(ProfileProperties)
	
	AccessKinds = ProfileProperties.AccessKinds.Unload();
	
	Filter = New Structure;
	Filter.Insert("PresetAccessKind", True);
	PresetAccessKinds = AccessKinds.FindRows(Filter);
	
	For Each PresetAccessKind In PresetAccessKinds Do
		AccessKinds.Delete(PresetAccessKind);
	EndDo;
	
	Return AccessKinds;
	
EndFunction

#EndRegion
