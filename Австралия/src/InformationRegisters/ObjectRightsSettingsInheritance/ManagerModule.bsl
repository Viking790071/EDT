#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Updates a hierarchy of object right setting owners.
// For example, a hierarchy of the FilesFolders catalog items.
//
// Parameters:
//  RightsSettingsOwners - a reference, for example, CatalogRef.FilesFolders or another type used to 
//                          configure the rights directly.
//                        - Rights owner type, for example, ("CatalogRef.FilesFolders")Type.
//                        - Array of values of the types specified above.
//                        - Undefined - no filtering for all types.
//                        - Object, for example, CatalogObject.FilesFolders. When passing an object, 
//                          update is possible only if the object is to be written and it is changed 
//                          (the parent is changed).
//
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it does not change.
//                          
//
Procedure UpdateRegisterData(Val RightsSettingsOwners = Undefined, HasChanges = Undefined) Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	If RightsSettingsOwners = Undefined Then
		AvailableRights = AccessManagementInternalCached.RightsForObjectsRightsSettingsAvailable();
		
		Query = New Query;
		QueryText =
		"SELECT
		|	CurrentTable.Ref
		|FROM
		|	&CurrentTable AS CurrentTable";
		
		For each KeyAndValue In AvailableRights.ByFullNames Do
			
			Query.Text = StrReplace(QueryText, "&CurrentTable", KeyAndValue.Key);
			Selection = Query.Execute().Select();
			
			While Selection.Next() Do
				UpdateOwnerParents(Selection.Ref, HasChanges);
			EndDo;
		EndDo;
		
	ElsIf TypeOf(RightsSettingsOwners) = Type("Array") Then
		
		For each RightsSettingsOwner In RightsSettingsOwners Do
			UpdateOwnerParents(RightsSettingsOwner, HasChanges);
		EndDo;
	Else
		UpdateOwnerParents(RightsSettingsOwners, HasChanges);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Updates parents of object right settings owner.
// For example, the FilesFolders catalog.
// 
// Parameters:
//  RightsSettingsOwner - Ref - for example, CatalogRef.FilesFolders or another type used to 
//                         configure the rights directly.
//                       - Object - for example, CatalogObject.FilesFolders. When passing an object, 
//                         update is possible only if the object is to be written and it is changed 
//                         (the parent is changed).
//
//  HasChanges        - Boolean - (return value) - if recorded, True is set, otherwise, it is not 
//                         changed.
//
//  UpdateHierarchy     - Boolean - updates the subordinate hierarchy forcibly, regardless of any 
//                         changes to owner parents.
//
//  ObjectsWithChanges  - Array - for internal use only.
//
Procedure UpdateOwnerParents(RightsSettingsOwner, HasChanges = False, UpdateHierarchy = False, ObjectsWithChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	AvailableRights = AccessManagementInternalCached.RightsForObjectsRightsSettingsAvailable();
	OwnerType = TypeOf(RightsSettingsOwner);
	
	ErrorTitle =
		NStr("ru = 'Ошибка при обновлении иерархии владельцев прав по значениям доступа.'; en = 'An error occurred when updating the rights owner hierarchy by access values.'; pl = 'Podczas aktualizacji hierarchii posiadaczy praw według wartości dostępu wystąpił błąd.';es_ES = 'Ha ocurrido un error al actualizar la jerarquía de propietarios de derechos por valores de acceso.';es_CO = 'Ha ocurrido un error al actualizar la jerarquía de propietarios de derechos por valores de acceso.';tr = 'Hak sahibi hiyerarşisini erişim değerleriyle güncellerken bir hata oluştu.';it = 'Errore durante l''aggiornamento della gerarchia dei diritti di proprietario in base ai valori di accesso.';de = 'Beim Aktualisieren der Rechteinhaberhierarchie durch Zugriffswerte ist ein Fehler aufgetreten.'")
		+ Chars.LF
		+ Chars.LF;
	
	If AvailableRights.ByTypes.Get(OwnerType) = Undefined Then
		Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Для типа ""%1""
			           |не настроено использование настроек прав объектов.'; 
			           |en = 'For type ""%1""
			           |usage of object rights settings is not configured.'; 
			           |pl = 'Dla typu ""%1""
			           |nie jest skonfigurowano wykorzystanie ustawień praw obiektów.';
			           |es_ES = 'Para el tipo ""%1""
			           |no se ha ajustado el uso de ajustes de derechos de los objetos.';
			           |es_CO = 'Para el tipo ""%1""
			           |no se ha ajustado el uso de ajustes de derechos de los objetos.';
			           |tr = '""%1""
			           | türü için nesne hakları ayarlarının kullanılması ayarlanmamıştır.';
			           |it = 'Per il tipo ""%1""
			           |l''uso delle impostazioni dei diritti degli oggetti non è configurato.';
			           |de = 'Für den Typ ""%1""
			           |ist die Verwendung von Objektberechtigungseinstellungen nicht konfiguriert.'"),
			String(OwnerType));
	EndIf;
	
	If AvailableRights.ByRefsTypes.Get(OwnerType) = Undefined Then
		Ref = UsersInternal.ObjectRef(RightsSettingsOwner);
		Object = RightsSettingsOwner;
	Else
		Ref = RightsSettingsOwner;
		Object = Undefined;
	EndIf;
	
	Hierarchical = AvailableRights.HierarchicalTables.Get(OwnerType) <> Undefined;
	UpdateRequired = False;
	
	If Hierarchical Then
		ObjectParentProperties = ParentProperties(Ref);
		
		If Object <> Undefined Then
			// Checking the object for changes.
			If ObjectParentProperties.Ref <> Object.Parent Then
				UpdateRequired = True;
			EndIf;
			ObjectParentProperties.Ref      = Object.Parent;
			ObjectParentProperties.Inherit = SettingsInheritance(Object.Parent);
		Else
			UpdateRequired = True;
		EndIf;
	Else
		If Object = Undefined Then
			UpdateRequired = True;
		EndIf;
	EndIf;
	
	If NOT UpdateRequired Then
		Return;
	EndIf;
	
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.ObjectRightsSettingsInheritance");
	
	If Object = Undefined Then
		AdditionalProperties = Undefined;
	Else
		AdditionalProperties = New Structure("LeadingObjectBeforeWrite", Object);
	EndIf;
	
	BeginTransaction();
	Try
		Lock.Lock();
		
		RecordSet = CreateRecordSet();
		RecordSet.Filter.Object.Set(Ref);
		
		// Preparing object parents.
		If Hierarchical Then
			NewRecords = ObjectParents(Ref, Ref, ObjectParentProperties);
		Else
			NewRecords = AccessManagementInternalCached.BlankRecordSetTable(
				Metadata.InformationRegisters.ObjectRightsSettingsInheritance.FullName()).Get();
			
			NewRow = NewRecords.Add();
			NewRow.Object   = Ref;
			NewRow.Parent = Ref;
		EndIf;
		
		Data = New Structure;
		Data.Insert("RecordSet",           RecordSet);
		Data.Insert("NewRecords",            NewRecords);
		Data.Insert("AdditionalProperties", AdditionalProperties);
		
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateRecordSet(Data, HasCurrentChanges);
		
		If HasCurrentChanges Then
			StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
			HasChanges = True;
			
			If ObjectsWithChanges <> Undefined
			   AND ObjectsWithChanges.Find(Ref) = Undefined Then
				
				ObjectsWithChanges.Add(Ref);
			EndIf;
		EndIf;
		
		If Hierarchical AND (HasCurrentChanges OR UpdateHierarchy) Then
			UpdateOwnerHierarchy(Ref, HasChanges, ObjectsWithChanges);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Fills RecordSet with object parents including itself as a parent.
//
// Parameters:
//  Ref - Ref - a reference in the ObjectRef hierarchy or ObjectRef.
//  ObjectRef - Ref, Undefined - a reference to the initial object.
//  ObjectParentProperties - Structure - a structure with the following properties:
//                            * Ref - Ref - a reference to the source object parent that can differ 
//                                            from the parent recorded in the database.
//                                            
//                            * Inherit - Boolean - inheriting settings by the parent.
//
// Returns:
//  RecordSet - InformationRegisterRecordSet.InheritObjectsRightsSettings.
//
Function ObjectParents(Ref, ObjectRef = Undefined, ObjectParentProperties = "", GetInheritance = True) Export
	
	NewRecords = AccessManagementInternalCached.BlankRecordSetTable(
		Metadata.InformationRegisters.ObjectRightsSettingsInheritance.FullName()).Get();
	
	// Getting an inheritance flag of parent rights settings for the reference.
	If GetInheritance Then
		Inherit = SettingsInheritance(Ref);
	Else
		Inherit = True;
		NewRecords.Columns.Add("Level", New TypeDescription("Number"));
	EndIf;
	
	Row = NewRecords.Add();
	Row.Object      = Ref;
	Row.Parent    = Ref;
	Row.Inherit = Inherit;
	
	If Not Inherit Then
		Return NewRecords;
	EndIf;
	
	If Ref = ObjectRef Then
		CurrentParentProperties = ObjectParentProperties;
	Else
		CurrentParentProperties = ParentProperties(Ref);
	EndIf;
	
	While ValueIsFilled(CurrentParentProperties.Ref) Do
	
		Row = NewRecords.Add();
		Row.Object   = Ref;
		Row.Parent = CurrentParentProperties.Ref;
		Row.UsageLevel = 1;
		
		If NOT GetInheritance Then
			Row.Level = Row.Parent.Level();
		EndIf;
		
		If Not CurrentParentProperties.Inherit Then
			Break;
		EndIf;
		
		CurrentParentProperties = ParentProperties(CurrentParentProperties.Ref);
	EndDo;
	
	Return NewRecords;
	
EndFunction

Function SettingsInheritance(Ref) Export
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	
	Query.Text =
	"SELECT
	|	SettingsInheritance.Inherit
	|FROM
	|	InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|WHERE
	|	SettingsInheritance.Object = &Ref
	|	AND SettingsInheritance.Parent = &Ref";
	
	Selection = Query.Execute().Select();
	
	Return ?(Selection.Next(), Selection.Inherit, True);
	
EndFunction

// For the UpdateOwnerParents procedure.
Procedure UpdateOwnerHierarchy(Ref, HasChanges, ObjectsWithChanges)
	
	// Updating the list of item parents in the current value hierarchy.
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	|	TableWithHierarchy.Ref AS SubordinateRef
	|FROM
	|	&TableWithHierarchy AS TableWithHierarchy
	|WHERE
	|	TableWithHierarchy.Ref IN HIERARCHY(&Ref)
	|	AND TableWithHierarchy.Ref <> &Ref";
	
	Query.Text = StrReplace(
		Query.Text, "&TableWithHierarchy", Ref.Metadata().FullName() );
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRecords = ObjectParents(Selection.SubordinateRef, Ref);
		
		RecordSet = CreateRecordSet();
		RecordSet.Filter.Object.Set(Selection.SubordinateRef);
		
		Data = New Structure;
		Data.Insert("RecordSet", RecordSet);
		Data.Insert("NewRecords",  NewRecords);
		
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateRecordSet(Data, HasCurrentChanges);
		
		If HasCurrentChanges Then
			StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
			HasChanges = True;
			
			If ObjectsWithChanges <> Undefined
			   AND ObjectsWithChanges.Find(Ref) = Undefined Then
				
				ObjectsWithChanges.Add(Ref);
			EndIf;
		EndIf;
		
	EndDo;
	
EndProcedure

// For the UpdateOwnerParents and ObjectParents procedures.
Function ParentProperties(Ref)
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	|	CurrentTable.Parent
	|INTO RefParent
	|FROM
	|	ObjectsTable AS CurrentTable
	|WHERE
	|	CurrentTable.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RefParent.Parent
	|FROM
	|	RefParent AS RefParent
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Parents.Inherit AS Inherit
	|FROM
	|	InformationRegister.ObjectRightsSettingsInheritance AS Parents
	|WHERE
	|	Parents.Object = Parents.Parent
	|	AND Parents.Object IN
	|			(SELECT
	|				RefParent.Parent
	|			FROM
	|				RefParent AS RefParent)";
	
	Query.Text = StrReplace(Query.Text, "ObjectsTable", Ref.Metadata().FullName());
	
	QueryResults = Query.ExecuteBatch();
	Selection = QueryResults[1].Select();
	Parent = ?(Selection.Next(), Selection.Parent, Undefined);
	
	Selection = QueryResults[2].Select();
	Inherit = ?(Selection.Next(), Selection.Inherit, True);
	
	Return New Structure("Ref, Inherit", Parent, Inherit);
	
EndFunction

#EndRegion

#EndIf
