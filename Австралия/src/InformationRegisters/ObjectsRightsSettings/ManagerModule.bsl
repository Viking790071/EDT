#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Updates available rights for object rights settings and saves the content of the latest changes.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if changes are found, True is set, otherwise, it is not 
//                  changed.
//
Procedure UpdateAvailableRightsForObjectsRightsSettings(HasChanges = Undefined) Export
	
	AvailableRights = AvailableRights();
	
	BeginTransaction();
	Try
		HasCurrentChanges = False;
		
		StandardSubsystemsServer.UpdateApplicationParameter(
			"StandardSubsystems.AccessManagement.RightsForObjectsRightsSettingsAvailable",
			AvailableRights, HasCurrentChanges);
		
		StandardSubsystemsServer.AddApplicationParameterChanges(
			"StandardSubsystems.AccessManagement.RightsForObjectsRightsSettingsAvailable",
			?(HasCurrentChanges,
			  New FixedStructure("HasChanges", True),
			  New FixedStructure()) );
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If HasCurrentChanges Then
		HasChanges = True;
	EndIf;
	
EndProcedure

// Updates auxiliary register data after changing rights based on access values saved to access 
// restriction parameters.
//
Procedure UpdateAuxiliaryRegisterDataByConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		"StandardSubsystems.AccessManagement.RightsForObjectsRightsSettingsAvailable");
		
	If LastChanges = Undefined Then
		UpdateRequired = True;
	Else
		UpdateRequired = False;
		For each ChangesPart In LastChanges Do
			
			If TypeOf(ChangesPart) = Type("FixedStructure")
			   AND ChangesPart.Property("HasChanges")
			   AND TypeOf(ChangesPart.HasChanges) = Type("Boolean") Then
				
				If ChangesPart.HasChanges Then
					UpdateRequired = True;
					Break;
				EndIf;
			Else
				UpdateRequired = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If UpdateRequired Then
		UpdateAuxiliaryRegisterData();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Returns the object right settings.
//
// Parameters:
//  ObjectRef - a reference to the object, for which reading of right settings is required.
//
// Returns:
//  Structure
//    Inherit        - Boolean - a flag of inheriting parent right settings.
//    Settings - ValueTable
//                         - SettingOwner - a reference to an object or an object parent (from the 
//                                                   object parent hierarchy).
//                         - InheritanceAllowed - Boolean - inheritance allowed.
//                         - User          - CatalogRef.Users
//                                                   CatalogRef.UserGroups
//                                                   CatalogRef.ExternalUsers
//                                                   CatalogRef.ExternalUserGroups.
//                         - <RightName1>           - Undefined, Boolean
//                                                       Undefined - the right is not configured,
//                                                       True       - the right is allowed,
//                                                       False         - the right is restricted.
//                         - <RightName2>           - ...
//
Function Read(Val ObjectRef) Export
	
	AvailableRights = AccessManagementInternalCached.RightsForObjectsRightsSettingsAvailable();
	
	RightsDetails = AvailableRights.ByTypes.Get(TypeOf(ObjectRef));
	
	If RightsDetails = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '???????????? ?? ?????????????????? InformationRegisters.ObjectsRightsSettings.Read()
			           |
			           |???????????????? ???????????????? ?????????????????? ObjectRef""%1"".
			           |?????? ???????????????? ?????????????? ""%2"" ?????????? ???? ??????????????????????????.'; 
			           |en = 'An error occurred in the InformationRegisters.ObjectsRightsSettings.Read() procedure
			           |
			           |Incorrect ObjectRef parameter value ""%1"".
			           |Rights are not set for the table ""%2"" objects.'; 
			           |pl = 'B????d procedury InformationRegisters.ObjectsRightsSettings.Read() 
			           |
			           |B????dna warto???? atrybutu ObjectRef""%1"".
			           |Rrawa nie zosta??y ustawione dla obiekt??w tablicy ""%2"".';
			           |es_ES = 'Error en el procedimiento InformationRegisters.ObjectsRightsSettings.Read()
			           |
			           |Valor incorrecto del par??metro ObjectRef ""%1"".
			           |Para los objetos de la tabla ""%2"" los derechos no se ajustan.';
			           |es_CO = 'Error en el procedimiento InformationRegisters.ObjectsRightsSettings.Read()
			           |
			           |Valor incorrecto del par??metro ObjectRef ""%1"".
			           |Para los objetos de la tabla ""%2"" los derechos no se ajustan.';
			           |tr = 'BilgiKay??tlar?? prosed??r??nde hata olu??tu. NesneHaklar??Ayarlar??.Read ()
			           |
			           | NesneReferans??%1 parametresinin yanl???? de??eri. 
			           |Tablo nesneleri i??in haklar %2 ayarlanmam????t??r.';
			           |it = 'Errore nella procedura InformationRegisters.ObjectsRightsSettings.Read()
			           |
			           |Il valore del parametro ObjectRef ""%1"" non ?? corretto.
			           |I diritti per gli oggetti della tabella ""%2"" non sono configurati.';
			           |de = 'Fehler in der Prozedur InformationRegisters.ObjectsRightsSettings.Read()
			           |
			           |Falscher Wert des Parameters ObjectRef ""%1"".
			           |F??r die Tabellenobjekte ""%2"" werden keine Berechtigungen gesetzt.'"),
			String(ObjectRef),
			ObjectRef.Metadata().FullName());
	EndIf;
	
	RightsSettings = New Structure;
	
	// Getting the inheritance setting value.
	RightsSettings.Insert("Inherit",
		InformationRegisters.ObjectRightsSettingsInheritance.SettingsInheritance(ObjectRef));
	
	// Preparing the right settings table structure.
	Settings = New ValueTable;
	Settings.Columns.Add("User");
	Settings.Columns.Add("SettingsOwner");
	Settings.Columns.Add("InheritanceIsAllowed", New TypeDescription("Boolean"));
	Settings.Columns.Add("ParentSetting",     New TypeDescription("Boolean"));
	For each RightDetails In RightsDetails Do
		Settings.Columns.Add(RightDetails.Key);
	EndDo;
	
	If AvailableRights.HierarchicalTables.Get(TypeOf(ObjectRef)) = Undefined Then
		SettingsInheritance = AccessManagementInternalCached.BlankRecordSetTable(
			Metadata.InformationRegisters.ObjectRightsSettingsInheritance.FullName()).Get();
		NewRow = SettingsInheritance.Add();
		SettingsInheritance.Columns.Add("Level", New TypeDescription("Number"));
		NewRow.Object   = ObjectRef;
		NewRow.Parent = ObjectRef;
	Else
		SettingsInheritance = InformationRegisters.ObjectRightsSettingsInheritance.ObjectParents(
			ObjectRef, , , False);
	EndIf;
	
	// Reading object settings and settings of parent objects inherited by the object.
	Query = New Query;
	Query.SetParameter("Object", ObjectRef);
	Query.SetParameter("SettingsInheritance", SettingsInheritance);
	Query.Text =
	"SELECT
	|	SettingsInheritance.Object AS Object,
	|	SettingsInheritance.Parent AS Parent,
	|	SettingsInheritance.Level AS Level
	|INTO SettingsInheritance
	|FROM
	|	&SettingsInheritance AS SettingsInheritance
	|
	|INDEX BY
	|	SettingsInheritance.Object,
	|	SettingsInheritance.Parent
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SettingsInheritance.Parent AS SettingsOwner,
	|	ObjectsRightsSettings.User AS User,
	|	ObjectsRightsSettings.UserRight AS Right,
	|	CASE
	|		WHEN SettingsInheritance.Parent <> &Object
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ParentSetting,
	|	ObjectsRightsSettings.RightIsProhibited AS RightIsProhibited,
	|	ObjectsRightsSettings.InheritanceIsAllowed AS InheritanceIsAllowed
	|FROM
	|	InformationRegister.ObjectsRightsSettings AS ObjectsRightsSettings
	|		INNER JOIN SettingsInheritance AS SettingsInheritance
	|		ON ObjectsRightsSettings.Object = SettingsInheritance.Parent
	|WHERE
	|	(SettingsInheritance.Parent = &Object
	|			OR ObjectsRightsSettings.InheritanceIsAllowed)
	|
	|ORDER BY
	|	ParentSetting DESC,
	|	SettingsInheritance.Level,
	|	ObjectsRightsSettings.SettingsOrder";
	Table = Query.Execute().Unload();
	
	CurrentSettingOwner = Undefined;
	CurrentUser = Undefined;
	For each Row In Table Do
		If CurrentSettingOwner <> Row.SettingsOwner
		 OR CurrentUser <> Row.User Then
			CurrentSettingOwner = Row.SettingsOwner;
			CurrentUser      = Row.User;
			Setting = Settings.Add();
			Setting.User      = Row.User;
			Setting.SettingsOwner = Row.SettingsOwner;
			Setting.ParentSetting = Row.ParentSetting;
		EndIf;
		If Settings.Columns.Find(Row.Right) = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '???????????? ?? ?????????????????? InformationRegisters.ObjectsRightsSettings.Read()
				           |
				           |?????? ???????????????? ?????????????? ""%1""
				           |?????????? ""%2"" ???? ??????????????????????????, ???????????? ?????? ????????????????
				           |?? ???????????????? ???????????????? ObjectsRightsSettings ??????
				           |?????????????? ""%3"".
				           |
				           |????????????????, ???????????????????? ???????????????????????????? ????????
				           |???? ?????????????????? ?????? ?????????????????? ?? ??????????????.
				           |?????????????????? ?????????????????? ???????????? ????????????????.'; 
				           |en = 'An error occurred in the InformationRegisters.ObjectsRightsSettings.Read() procedure
				           |
				           |Right ""%2"" is not set 
				           |for the ""%1"" table objects, 
				           |but it is written
				           |to the ObjectsRightsSettings information register
				           |for object ""%3"".
				           |
				           |Maybe, the infobase is not updated or there are update errors.
				           |Change the register data.'; 
				           |pl = 'B????d w procedurze InformationRegisters.ObjectsRightsSettings.Read() 
				           |
				           |Prawo""%2"" nie zosta??o ustawione 
				           |dla""%1"" obiekt??w tablicy, 
				           |ale jest ono
				           |zapisane w rejestrze informacji ObjectsRightsSettings
				           |dla obiektu""%3"".
				           |
				           |By?? mo??e aktualizacja bazy, nie zosta??a wykonana lub zosta??a wykonana z b????dami.
				           |Zmie?? dane rejestru.';
				           |es_ES = 'Error en el procedimiento InformationRegisters.ObjectRightsSettings.Read()
				           |
				           |el %2 derecho
				           |no est?? establecido para los objetos de la
				           |%1 tabla, aunque, se ha
				           |grabado en el registro de informaci??n ObjectsRightsSettings para el %3 objeto.
				           |
				           |La actualizaci??n de la infobase
				           |puede no haberse ejecutado, o ejecutado con un error.
				           |Se requiere la correcci??n de los datos de registro.';
				           |es_CO = 'Error en el procedimiento InformationRegisters.ObjectRightsSettings.Read()
				           |
				           |el %2 derecho
				           |no est?? establecido para los objetos de la
				           |%1 tabla, aunque, se ha
				           |grabado en el registro de informaci??n ObjectsRightsSettings para el %3 objeto.
				           |
				           |La actualizaci??n de la infobase
				           |puede no haberse ejecutado, o ejecutado con un error.
				           |Se requiere la correcci??n de los datos de registro.';
				           |tr = 'BilgiKay??tlar?? prosed??r??nde hata olu??tu. NesneHaklar??Ayarlar??. Read () 
				           |
				           |tablonun nesneleri %2 i??in
				           | ayarlanmayan haklar, ancak
				           |nnesne i??in NesneHaklar??Ayarlar?? bilgi kayd??na yaz??l??r.%1
				           | Veritaban?? g??ncellemesi bir
				           |
				           | hata ile y??r??t??lm???? veya y??r??t??lmemi?? olabilir %3
				           |
				           |Kay??t verileri d??zeltilmek i??in gereklidir.';
				           |it = 'Errore nella procedura InformationRegisters.ObjectsRightsSettings.Read() 
				           |
				           |I diritti ""%2"" per gli oggetti della 
				           |tabella ""%1"" non sono congifurati, 
				           |ma sono scritti
				           |nel registro informazioni ObjectsRightsSettings
				           |per l''oggetto ""%3"".
				           |
				           |L''infobase potrebbe non essere aggiornato o potrebbero esserci errori di aggiornamento.
				           |Modificare dati del registro.';
				           |de = 'Fehler in der InformationRegisters.ObjectsRightsSettings.Read()
				           |
				           |das %2 Recht
				           |wird nicht f??r Objekte der
				           |%1 Tabelle festgelegt, jedoch wird es in
				           |das Informationsregister ObjectsRightsSettings der %3 Objekte geschrieben.
				           |
				           |Das Infobaseupdate
				           |wurde m??glicherweise nicht ausgef??hrt oder mit einem Fehler ausgef??hrt.
				           |Registerdaten m??ssen korrigiert werden.'"),
				ObjectRef.Metadata().FullName(),
				Row.Right,
				String(ObjectRef));
		EndIf;
		Setting.InheritanceIsAllowed = Setting.InheritanceIsAllowed OR Row.InheritanceIsAllowed;
		Setting[Row.Right] = NOT Row.RightIsProhibited;
	EndDo;
	
	RightsSettings.Insert("Settings", Settings);
	
	Return RightsSettings;
	
EndFunction

// Writes the object right settings.
//
// Parameters:
//  Inherit - Boolean - a flag of inheriting parent right settings.
//  Settings - ValueTable with a structure returned by the Read() function. Only rows whose 
//                SettingOwner = ObjectRef are saved.
//
Procedure Write(Val ObjectRef, Val Settings, Val Inherit) Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	AvailableRights = AccessManagementInternalCached.RightsForObjectsRightsSettingsAvailable();
	RightsDetails = AvailableRights.ByRefsTypes.Get(TypeOf(ObjectRef));
	
	If RightsDetails = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '???????????? ?? ?????????????????? InformationRegisters.ObjectsRightsSettings.Read()
			           |
			           |???????????????? ???????????????? ?????????????????? ObjectRef""%1"".
			           |?????? ???????????????? ?????????????? ""%2"" ?????????? ???? ??????????????????????????.'; 
			           |en = 'An error occurred in the InformationRegisters.ObjectsRightsSettings.Read() procedure
			           |
			           |Incorrect ObjectRef parameter value ""%1"".
			           |Rights are not set for the table ""%2"" objects.'; 
			           |pl = 'Wyst??pi?? b????d w procedurze InformationRegisters.ObjectsRightsSettings.Read() 
			           |
			           |B????dna warto???? atrybutu ObjectRef ""%1"".
			           |Prawa nie zosta??y ustawione dla obiekt??w tablicy ""%2"".';
			           |es_ES = 'Error en el procedimiento InformationRegisters.ObjectsRightsSettings.Read()
			           |
			           |Valor incorrecto del par??metro ObjectRef ""%1"".
			           |Para los objetos de la tabla ""%2"" los derechos no se ajustan.';
			           |es_CO = 'Error en el procedimiento InformationRegisters.ObjectsRightsSettings.Read()
			           |
			           |Valor incorrecto del par??metro ObjectRef ""%1"".
			           |Para los objetos de la tabla ""%2"" los derechos no se ajustan.';
			           |tr = 'BilgiKay??tlar?? prosed??r??nde hata olu??tu. NesneHaklar??Ayarlar??.Read ()
			           |
			           | NesneReferans??%1 parametresinin yanl???? de??eri. 
			           |Tablo nesneleri i??in haklar %2 ayarlanmam????t??r.';
			           |it = 'Errore nella procedura InformationRegisters.ObjectsRightsSettings.Read()
			           |
			           |Il valore del parametro ObjectRef ""%1"" non ?? corretto.
			           |I diritti per gli oggetti della tabella ""%2"" non sono configurati.';
			           |de = 'Fehler in der Prozedur InformationRegisters.ObjectsRightsSettings.Read()
			           |
			           |Falscher Wert des Parameters ObjectRef""%1"".
			           |F??r die Tabellenobjekte ""%2"" werden keine Berechtigungen gesetzt.'"),
			String(ObjectRef),
			ObjectRef.Metadata().FullName());
	EndIf;
	
	// Setting the inheritance setting flag.
	RecordSet = InformationRegisters.ObjectRightsSettingsInheritance.CreateRecordSet();
	RecordSet.Filter.Object.Set(ObjectRef);
	RecordSet.Filter.Parent.Set(ObjectRef);
	RecordSet.Read();
	
	If RecordSet.Count() = 0 Then
		ChangedInheritance = True;
		NewRecord = RecordSet.Add();
		NewRecord.Object      = ObjectRef;
		NewRecord.Parent    = ObjectRef;
		NewRecord.Inherit = Inherit;
	Else
		ChangedInheritance = RecordSet[0].Inherit <> Inherit;
		RecordSet[0].Inherit = Inherit;
	EndIf;
	
	// Preparing new settings
	NewRightsSettings = AccessManagementInternalCached.BlankRecordSetTable(
		Metadata.InformationRegisters.ObjectsRightsSettings.FullName()).Get();
	
	CommonRightsTable = Catalogs.MetadataObjectIDs.EmptyRef();
	
	Filter = New Structure("SettingsOwner", ObjectRef);
	SettingsOrder = 0;
	For each Setting In Settings.FindRows(Filter) Do
		For each RightDetails In RightsDetails Do
			If TypeOf(Setting[RightDetails.Name]) <> Type("Boolean") Then
				Continue;
			EndIf;
			SettingsOrder = SettingsOrder + 1;
			
			RightsSetting = NewRightsSettings.Add();
			RightsSetting.SettingsOrder      = SettingsOrder;
			RightsSetting.Object                = ObjectRef;
			RightsSetting.User          = Setting.User;
			RightsSetting.UserRight                 = RightDetails.Name;
			RightsSetting.RightIsProhibited        = NOT Setting[RightDetails.Name];
			RightsSetting.InheritanceIsAllowed = Setting.InheritanceIsAllowed;
			// Cache attributes
			RightsSetting.RightPermissionLevel =
				?(RightsSetting.RightIsProhibited, 0, ?(RightsSetting.InheritanceIsAllowed, 2, 1));
			RightsSetting.RightProhibitionLevel =
				?(RightsSetting.RightIsProhibited, ?(RightsSetting.InheritanceIsAllowed, 2, 1), 0);
			
			AddedIndividualTablesSettings = False;
			For each KeyAndValue In AvailableRights.SeparateTables Do
				SeparateTable = KeyAndValue.Key;
				ReadTable    = RightDetails.ReadInTables.Find(   SeparateTable) <> Undefined;
				TableChange = RightDetails.ChangeInTables.Find(SeparateTable) <> Undefined;
				If NOT ReadTable AND NOT TableChange Then
					Continue;
				EndIf;
				AddedIndividualTablesSettings = True;
				TableRightsSettings = NewRightsSettings.Add();
				FillPropertyValues(TableRightsSettings, RightsSetting);
				TableRightsSettings.Table = SeparateTable;
				If ReadTable Then
					TableRightsSettings.ReadingPermissionLevel = RightsSetting.RightPermissionLevel;
					TableRightsSettings.ReadingProhibitionLevel = RightsSetting.RightProhibitionLevel;
				EndIf;
				If TableChange Then
					TableRightsSettings.ChangingPermissionLevel = RightsSetting.RightPermissionLevel;
					TableRightsSettings.ChangingProhibitionLevel = RightsSetting.RightProhibitionLevel;
				EndIf;
			EndDo;
			
			CommonRead    = RightDetails.ReadInTables.Find(   CommonRightsTable) <> Undefined;
			CommonChange = RightDetails.ChangeInTables.Find(CommonRightsTable) <> Undefined;
			
			If NOT CommonRead AND NOT CommonChange AND AddedIndividualTablesSettings Then
				NewRightsSettings.Delete(RightsSetting);
			Else
				If CommonRead Then
					RightsSetting.ReadingPermissionLevel = RightsSetting.RightPermissionLevel;
					RightsSetting.ReadingProhibitionLevel = RightsSetting.RightProhibitionLevel;
				EndIf;
				If CommonChange Then
					RightsSetting.ChangingPermissionLevel = RightsSetting.RightPermissionLevel;
					RightsSetting.ChangingProhibitionLevel = RightsSetting.RightProhibitionLevel;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	// Writing object right settings and an inheritance flag of right settings.
	BeginTransaction();
	Try
		Data = New Structure;
		Data.Insert("RecordSet",   InformationRegisters.ObjectsRightsSettings);
		Data.Insert("NewRecords",    NewRightsSettings);
		Data.Insert("FilterField",     "Object");
		Data.Insert("FilterValue", ObjectRef);
		
		HasChanges = False;
		AccessManagementInternal.UpdateRecordSet(Data, HasChanges);
		
		If HasChanges Then
			ObjectsWithChanges = New Array;
		Else
			ObjectsWithChanges = Undefined;
		EndIf;
		
		If ChangedInheritance Then
			StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
			RecordSet.Write();
			InformationRegisters.ObjectRightsSettingsInheritance.UpdateOwnerParents(
				ObjectRef, , True, ObjectsWithChanges);
		EndIf;
		
		If ObjectsWithChanges <> Undefined Then
			AddHierarchyObjects(ObjectRef, ObjectsWithChanges);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Updates auxiliary register data when changing the configuration.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure UpdateAuxiliaryRegisterData(HasChanges = Undefined) Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	SetPrivilegedMode(True);
	
	AvailableRights = AccessManagementInternalCached.RightsForObjectsRightsSettingsAvailable();
	
	RightsTables = New ValueTable;
	RightsTables.Columns.Add("RightsOwner", Metadata.InformationRegisters.ObjectsRightsSettings.Dimensions.Object.Type);
	RightsTables.Columns.Add("UserRight",        Metadata.InformationRegisters.ObjectsRightsSettings.Dimensions.UserRight.Type);
	RightsTables.Columns.Add("Table",      Metadata.InformationRegisters.ObjectsRightsSettings.Dimensions.Table.Type);
	RightsTables.Columns.Add("Read",       New TypeDescription("Boolean"));
	RightsTables.Columns.Add("Update",    New TypeDescription("Boolean"));
	
	BlankRefsRightsOwner = AccessManagementInternalCached.BlankRefsMapToSpecifiedRefsTypes(
		"InformationRegister.ObjectsRightsSettings.Dimension.Object");
	
	Filter = New Structure;
	For each KeyAndValue In AvailableRights.ByRefsTypes Do
		RightsOwnerType = KeyAndValue.Key;
		RightsDetails     = KeyAndValue.Value;
		
		If BlankRefsRightsOwner.Get(RightsOwnerType) = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '???????????? ?? ?????????????????? UpdateAuxiliaryRegisterData
				           |???????????? ?????????????????? ???????????????? ???????????????? ObjectsRightsSettings.
				           |
				           |?????? ???????????????????? ???????? ""%1"" ???? ???????????? ?? ?????????????????? Object.'; 
				           |en = 'An error occurred in the UpdateAuxiliaryRegisterData procedure
				           |of the manager module of the ObjectsRightsSettings information register.
				           |
				           |""%1"" rights owner type is not specified in dimension Object.'; 
				           |pl = 'B????d UpdateAuxiliaryRegisterData procedure
				           |modu??u mened??era rejestru informacji ObjectsRightsSettings.
				           |
				           |""%1"" w wymiarze Object nie okre??lono rodzaju posiadacza praw.';
				           |es_ES = 'Error en
				           |el procedimiento UpdateSubordinateRegisterData del m??dulo gestor del registro de informaci??n ObjectsRightsSettings.
				           |
				           |Tipo del %1 propietario de derechos no est?? especificado en la dimensi??n Objeto.';
				           |es_CO = 'Error en
				           |el procedimiento UpdateSubordinateRegisterData del m??dulo gestor del registro de informaci??n ObjectsRightsSettings.
				           |
				           |Tipo del %1 propietario de derechos no est?? especificado en la dimensi??n Objeto.';
				           |tr = 'ObjectsRightsSettings bilgi kayd??n??n y??netici mod??l??n??n
				           |UpdateAuxiliaryRegisterData prosed??r??nde hata olu??tu.
				           |
				           |""%1"" yetki sahibi t??r?? Object boyutunda belirtilmemi??.';
				           |it = 'Errore nella procedura UpdateAuxiliaryRegisterData
				           |del modulo di gestione del registro informazioni ObjectsRightsSettings.
				           |
				           |""%1""Il tipo di proprietario dei diritti non ?? specificato nella dimensione Oggetto.';
				           |de = 'Fehler in
				           |der Prozedur zum UpdateAuxiliaryRegisterData des Managermoduls des Informationsregisters ObjectsRightsSettings.
				           |
				           |Der Typ des %1 Rechteinhabers ist in der Dimension Object nicht angegeben.'"),
				RightsOwnerType);
		EndIf;
		
		Filter.Insert("RightsOwner", BlankRefsRightsOwner.Get(RightsOwnerType));
		For each RightDetails In RightsDetails Do
			Filter.Insert("UserRight", RightDetails.Name);
			
			For each Table In RightDetails.ReadInTables Do
				Row = RightsTables.Add();
				FillPropertyValues(Row, Filter);
				Row.Table = Table;
				Row.Read = True;
			EndDo;
			
			For each Table In RightDetails.ChangeInTables Do
				Filter.Insert("Table", Table);
				Rows = RightsTables.FindRows(Filter);
				If Rows.Count() = 0 Then
					Row = RightsTables.Add();
					FillPropertyValues(Row, Filter);
				Else
					Row = Rows[0];
				EndIf;
				Row.Update = True;
			EndDo;
		EndDo;
	EndDo;
	
	TemporaryTablesQueriesText =
	"SELECT
	|	RightsTables.RightsOwner,
	|	RightsTables.UserRight,
	|	RightsTables.Table,
	|	RightsTables.Read,
	|	RightsTables.Update
	|INTO RightsTables
	|FROM
	|	&RightsTables AS RightsTables
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsSettings.Object AS Object,
	|	RightsSettings.User AS User,
	|	RightsSettings.UserRight AS UserRight,
	|	MAX(RightsSettings.RightIsProhibited) AS RightIsProhibited,
	|	MAX(RightsSettings.InheritanceIsAllowed) AS InheritanceIsAllowed,
	|	MAX(RightsSettings.SettingsOrder) AS SettingsOrder
	|INTO RightsSettings
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
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.UserRight,
	|	ISNULL(RightsTables.Table, VALUE(Catalog.MetadataObjectIDs.EmptyRef)) AS Table,
	|	RightsSettings.RightIsProhibited,
	|	RightsSettings.InheritanceIsAllowed,
	|	RightsSettings.SettingsOrder,
	|	CASE
	|		WHEN RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS RightPermissionLevel,
	|	CASE
	|		WHEN NOT RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS RightProhibitionLevel,
	|	CASE
	|		WHEN NOT ISNULL(RightsTables.Read, FALSE)
	|			THEN 0
	|		WHEN RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ReadingPermissionLevel,
	|	CASE
	|		WHEN NOT ISNULL(RightsTables.Read, FALSE)
	|			THEN 0
	|		WHEN NOT RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ReadingProhibitionLevel,
	|	CASE
	|		WHEN NOT ISNULL(RightsTables.Update, FALSE)
	|			THEN 0
	|		WHEN RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ChangingPermissionLevel,
	|	CASE
	|		WHEN NOT ISNULL(RightsTables.Update, FALSE)
	|			THEN 0
	|		WHEN NOT RightsSettings.RightIsProhibited
	|			THEN 0
	|		WHEN RightsSettings.InheritanceIsAllowed
	|			THEN 2
	|		ELSE 1
	|	END AS ChangingProhibitionLevel
	|INTO NewData
	|FROM
	|	RightsSettings AS RightsSettings
	|		LEFT JOIN RightsTables AS RightsTables
	|		ON (VALUETYPE(RightsSettings.Object) = VALUETYPE(RightsTables.RightsOwner))
	|			AND RightsSettings.UserRight = RightsTables.UserRight
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP RightsTables
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP RightsSettings";
	
	QueryText =
	"SELECT
	|	NewData.Object,
	|	NewData.User,
	|	NewData.UserRight,
	|	NewData.Table,
	|	NewData.RightIsProhibited,
	|	NewData.InheritanceIsAllowed,
	|	NewData.SettingsOrder,
	|	NewData.RightPermissionLevel,
	|	NewData.RightProhibitionLevel,
	|	NewData.ReadingPermissionLevel,
	|	NewData.ReadingProhibitionLevel,
	|	NewData.ChangingPermissionLevel,
	|	NewData.ChangingProhibitionLevel,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array;
	Fields.Add(New Structure("Object"));
	Fields.Add(New Structure("User"));
	Fields.Add(New Structure("UserRight"));
	Fields.Add(New Structure("Table"));
	Fields.Add(New Structure("RightIsProhibited"));
	Fields.Add(New Structure("InheritanceIsAllowed"));
	Fields.Add(New Structure("SettingsOrder"));
	Fields.Add(New Structure("RightPermissionLevel"));
	Fields.Add(New Structure("RightProhibitionLevel"));
	Fields.Add(New Structure("ReadingPermissionLevel"));
	Fields.Add(New Structure("ReadingProhibitionLevel"));
	Fields.Add(New Structure("ChangingPermissionLevel"));
	Fields.Add(New Structure("ChangingProhibitionLevel"));
	
	Query = New Query;
	Query.SetParameter("RightsTables", RightsTables);
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.ObjectsRightsSettings", TemporaryTablesQueriesText);
	
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.ObjectsRightsSettings");
	
	BeginTransaction();
	Try
		Lock.Lock();
		
		Data = New Structure;
		Data.Insert("RegisterManager",      InformationRegisters.ObjectsRightsSettings);
		Data.Insert("EditStringContent", Query.Execute().Unload());
		
		AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// See InformationRegisters.ObjectsRightsSettings.AvailableRights. 
Function RightsForObjectsRightsSettingsAvailable() Export
	
	AvailableRights = StandardSubsystemsServer.ApplicationParameter(
		"StandardSubsystems.AccessManagement.RightsForObjectsRightsSettingsAvailable");
	
	If AvailableRights = Undefined Then
		UpdateAvailableRightsForObjectsRightsSettings();
	EndIf;
	
	AvailableRights = StandardSubsystemsServer.ApplicationParameter(
		"StandardSubsystems.AccessManagement.RightsForObjectsRightsSettingsAvailable");
	
	Return AvailableRights;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Procedure AddHierarchyObjects(Ref, ObjectsArray)
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Query.Text = StrReplace(
	"SELECT
	|	TableWithHierarchy.Ref
	|FROM
	|	ObjectsTable AS TableWithHierarchy
	|WHERE
	|	TableWithHierarchy.Ref IN HIERARCHY(&Ref)
	|	AND NOT TableWithHierarchy.Ref IN (&ObjectsArray)",
	"ObjectsTable",
	Ref.Metadata().FullName());
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ObjectsArray.Add(Selection.Ref);
	EndDo;
	
EndProcedure

// See AccessManagementOverridable.OnFillAvailableRightsForObjectsRightsSettings. 
Function AvailableRights()
	
	AvailableRights = New ValueTable();
	AvailableRights.Columns.Add("RightsOwner",        New TypeDescription("String"));
	AvailableRights.Columns.Add("Name",                 New TypeDescription("String", , New StringQualifiers(60)));
	AvailableRights.Columns.Add("Title",           New TypeDescription("String", , New StringQualifiers(60)));
	AvailableRights.Columns.Add("ToolTip",           New TypeDescription("String", , New StringQualifiers(150)));
	AvailableRights.Columns.Add("InitialValue",   New TypeDescription("Boolean,Number"));
	AvailableRights.Columns.Add("RequiredRights",      New TypeDescription("Array"));
	AvailableRights.Columns.Add("ReadInTables",     New TypeDescription("Array"));
	AvailableRights.Columns.Add("ChangeInTables",  New TypeDescription("Array"));
	
	SSLSubsystemsIntegration.OnFillAvailableRightsForObjectsRightsSettings(AvailableRights);
	AccessManagementOverridable.OnFillAvailableRightsForObjectsRightsSettings(AvailableRights);
	
	ErrorTitle =
		NStr("ru = '???????????? ?? ?????????????????? OnFillAvailableRightsForObjectsRightsSettings
		           |???????????? ???????????? AccessManagementOverridable.'; 
		           |en = 'An error occurred in the OnFillAvailableRightsForObjectsRightsSettings procedure 
		           |of the AccessManagementOverridable common module.'; 
		           |pl = 'B????d w procedurze OnFillAvailableRightsForObjectsRightsSettings 
		           |modu??u og??lnego AccessManagementOverridable.';
		           |es_ES = 'Error en el procedimiento OnFillAvailableRightsForObjectsRightsSettings
		           |del m??dulo com??n AccessManagementOverridable.';
		           |es_CO = 'Error en el procedimiento OnFillAvailableRightsForObjectsRightsSettings
		           |del m??dulo com??n AccessManagementOverridable.';
		           |tr = 'Eri??imY??netimiYenidenTan??mlanm????
		           | ortak mod??l??n??n NesneHaklar??nAyarlanmas??????inOlas??HaklarDolduruldu??unda prosed??r??nde bir hata olu??tu.';
		           |it = 'Errore nella procedura OnFillAvailableRightsForObjectsRightsSettings 
		           |del modulo generale AccessManagementOverridable.';
		           |de = 'Fehler bei der Prozedur OnFillAvailableRightsForObjectsRightsSettings
		           |des allgemeinen Moduls AccessManagementOverridable.'")
		+ Chars.LF
		+ Chars.LF;
	
	ByTypes              = New Map;
	ByRefsTypes        = New Map;
	ByFullNames       = New Map;
	OwnersTypes       = New Array;
	SeparateTables     = New Map;
	HierarchicalTables = New Map;
	
	TypeOfRightsOwnersToDefine  = AccessManagementInternalCached.TableFieldTypes("DefinedType.RightsSettingsOwner");
	TypeOfAccessValuesToDefine = AccessManagementInternalCached.TableFieldTypes("DefinedType.AccessValue");
	
	AccessKindsProperties = AccessManagementInternalCached.AccessKindsProperties();
	
	SubscriptionTypesUpdateRightsSettingsOwnersGroups = AccessManagementInternalCached.TableFieldTypes(
		"DefinedType.RightsSettingsOwnerObject");
	
	SubscriptionTypesWriteAccessValuesSets = AccessManagementInternalCached.ObjectsTypesInSubscriptionsToEvents(
		"WriteAccessValuesSets");
	
	SubscriptionTypesWriteDependentAccessValuesSets = AccessManagementInternalCached.ObjectsTypesInSubscriptionsToEvents(
		"WriteDependentAccessValuesSets");
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("RightsOwner");
	AdditionalParameters.Insert("CommonOwnersRights", New Map);
	AdditionalParameters.Insert("IndividualOwnersRights", New Map);
	
	OwnersRightsIndexes = New Map;
	
	For each PossibleRight In AvailableRights Do
		OwnerMetadataObject = Metadata.FindByFullName(PossibleRight.RightsOwner);
		
		If OwnerMetadataObject = Undefined Then
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '???? ???????????? ???????????????? ???????? ""%1"".'; en = 'Owner of rights ""%1"" is not found.'; pl = 'Nie znaleziono posiadacza praw ""%1"".';es_ES = 'Propietario de los derechos ""%1"" no encontrado.';es_CO = 'Propietario de los derechos ""%1"" no encontrado.';tr = 'Hak sahibi ""%1"" bulunamad??.';it = 'Il proprietario dei permessi ""%1"" non ?? stato trovato.';de = 'Inhaber der Rechte ""%1"" wurde nicht gefunden.'"),
				PossibleRight.RightsOwner);
		EndIf;
		
		AdditionalParameters.RightsOwner = PossibleRight.RightsOwner;
		
		FillIDs("ReadInTables",    PossibleRight, ErrorTitle, SeparateTables, AdditionalParameters);
		FillIDs("ChangeInTables", PossibleRight, ErrorTitle, SeparateTables, AdditionalParameters);
		
		OwnerRights = ByFullNames[PossibleRight.RightsOwner];
		If OwnerRights = Undefined Then
			OwnerRights = New Map;
			OwnerRightsArray = New Array;
			
			RefType = StandardSubsystemsServer.MetadataObjectReferenceOrMetadataObjectRecordKeyType(
				OwnerMetadataObject);
			
			ObjectType = StandardSubsystemsServer.MetadataObjectOrMetadataObjectRecordSetType(
				OwnerMetadataObject);
			
			If TypeOfRightsOwnersToDefine.Get(RefType) = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '?????? ?????????????????? ???????? ""%1""
					           |???? ???????????? ?? ???????????????????????? ???????? ""???????????????? ???????????????? ????????"".'; 
					           |en = '""%1"" rights owner type 
					           |is not specified in defined type ""Rights settings owner"".'; 
					           |pl = 'Typ w??a??ciciela praw ""%1""
					           |nie jest okre??lony w podym typie ""W??a??ciciel ustawie?? praw"".';
					           |es_ES = 'El tipo del propietario de derechos ""%1""
					           |no se ha indicado en el tipo predeterminado ""Propietario de ajustes de derechos"".';
					           |es_CO = 'El tipo del propietario de derechos ""%1""
					           |no se ha indicado en el tipo predeterminado ""Propietario de ajustes de derechos"".';
					           |tr = 'Hak sahibinin t??r??"
" %1 haklar??n??n t??r?? tan??mlanm???? t??r??nde belirtilmemi??.';
					           |it = 'Il tipo di proprietario dei diritti ""%1"" 
					           |non ?? indicato nel tipo definito ""Proprietario delle impostazioni dei diritti"".';
					           |de = 'Der Typ des Rechteinhabers ""%1""
					           |ist im festgelegten Typ ""Rechteinhaber-Einstellungen"" nicht angegeben.'"),
					String(RefType));
			EndIf;
			
			If (SubscriptionTypesWriteDependentAccessValuesSets.Get(ObjectType) <> Undefined
			      OR SubscriptionTypesWriteAccessValuesSets.Get(ObjectType) <> Undefined)
			    AND TypeOfAccessValuesToDefine.Get(RefType) = Undefined Then
				
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '?????? ?????????????????? ???????? ""%1""
					           |???? ???????????? ?? ???????????????????????? ???????? ""???????????????? ??????????????"",
					           |???? ???????????????????????? ?????? ???????????????????? ?????????????? ???????????????? ??????????????,
					           |??.??. ???????????? ?? ?????????? ???? ???????????????? ???? ??????????????:
					           |- WriteDependentAccessValuesSets*,
					           |- WriteAccessValuesSets*.
					           |?????????????????? ?????????????? ?????? ?? ???????????????????????? ???????? ""???????????????? ??????????????""
					           |?????? ?????????????????????? ???????????????????? ???????????????? AccessValuesSets.'; 
					           |en = '""%1"" rights owner type
					           |is not specified in defined type ""Access value"" 
					           |but used to fill access value sets 
					           |as it is specified in one of subscriptions to the event:
					           |- WriteDependentAccessValuesSets*,
					           |- WriteAccessValuesSets*.
					           |Specify a type in defined type ""Access value"" 
					           |for correct filling of the AccessValuesSets register.'; 
					           |pl = 'W definiowanym typie""%1"" Warto???? dost??pu
					           |nie okre??lono typu""Warto??ci dost??pu"" 
					           |jednak jest on u??ywany do wype??nienia zestaw??w warto??ci dost??pu 
					           |jak zosta?? okre??lony w jednej z subskrypcji wydarze??:
					           |- WriteDependentAccessValuesSets*,
					           |- WriteAccessValuesSets*.
					           |Nale??y okre??li?? typ w definiowanym typie ""Warto???? dost??pu"" 
					           |dla prawid??owego wype??nienia rejestru AccessValuesSets.';
					           |es_ES = 'Tipo del
					           |%1 propietario de derechos no est?? especificado en
					           |el tipo definido de valores de Acceso, pero utilizado
					           |para rellenar los conjuntos de valores de acceso, como est?? especificado en una de
					           |las suscripciones
					           |al evento: - WriteDependentAccessValuesSet*, - WriteAccessValuesSets*.
					           |Usted necesita especificar el tipo en
					           |el tipo especificado de valores de Acceso para un relleno correcto del registro de AccessValuesSets.';
					           |es_CO = 'Tipo del
					           |%1 propietario de derechos no est?? especificado en
					           |el tipo definido de valores de Acceso, pero utilizado
					           |para rellenar los conjuntos de valores de acceso, como est?? especificado en una de
					           |las suscripciones
					           |al evento: - WriteDependentAccessValuesSet*, - WriteAccessValuesSets*.
					           |Usted necesita especificar el tipo en
					           |el tipo especificado de valores de Acceso para un relleno correcto del registro de AccessValuesSets.';
					           |tr = 'Hak sahibinin
					           |t??r?? Eri??im de??eri tan??ml?? t??r??nde belirtilmemi?? 
					           |ancak aboneliklerden birinde belirtilen eri??im de??er 
					           |k??melerini doldurmak i??in kullan??l??r:
					           |- WriteDependentAccessValuesSets*,
					           |-WriteAccessValuesSets.
					           |AccessValuesSets
					           |kayd??n??n do??ru doldurulmas?? i??in belirtilen t??rdeki eri??im de??eri t??r??n?? %1 belirtmeniz gerekir.';
					           |it = 'Il tipo di proprietario dei diritti ""%1""
					           |non ?? specificato nel tipo definito ""Valore di accesso"" 
					           |ma ?? usato per compilare gli insiemi dei valori di accesso
					           |perch?? ?? specificato in una delle sottoscrizioni all''evento:
					           |- WriteDependentAccessValuesSets*,
					           |- WriteAccessValuesSets*.
					           |Specificare un tipo in tipo definito ""Valore di accesso"" 
					           |per una corretta compilazione del registro AccessValuesSets.';
					           |de = 'Der Typ des
					           |%1Rechteinhabers ist nicht im definierten Typ
					           |des Zugriffswerts angegeben, sondern
					           |zum F??llen der S??tze von Zugriffswerten, wie in einer
					           |der Subskriptionen
					           |f??r das Ereignis angegeben: - WriteDependentAccessValuesSets*, - WriteAccessValuesSets*.
					           |Sie m??ssen den Typ des angegebenen
					           |Zugriffswerttyps angeben das korrekte F??llen des Registers AccessValuesSets.'"),
					String(RefType));
			EndIf;
			
			If AccessKindsProperties.ByValuesTypes.Get(RefType) <> Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '?????? ?????????????????? ???????? ""%1""
					           |???? ?????????? ????????????????????????????, ?????? ?????? ???????????????? ??????????????,
					           |???? ?????????????????? ?? ???????????????? ???????? ?????????????? ""%2"".'; 
					           |en = '""%1"" rights owner type
					           |cannot be used as an access value type
					           |but it is detected in description of access kind ""%2"".'; 
					           |pl = 'Typ posiadacza praw ""%1""
					           |nie mo??e by?? u??ywany, jako typ warto??ci dost??pu,
					           |ale znajduje si?? w opisie typu dost??pu ""%2""';
					           |es_ES = 'El tipo del propietario de derechos ""%1""
					           |no puede ser usado como el tipo de valores de acceso,
					           |pero se ha encontrado en la descripci??n del tipo de acceso ""%2"".';
					           |es_CO = 'El tipo del propietario de derechos ""%1""
					           |no puede ser usado como el tipo de valores de acceso,
					           |pero se ha encontrado en la descripci??n del tipo de acceso ""%2"".';
					           |tr = 'Hak sahibinin t??r??, 
					           | %1 eri??im de??erlerinin t??r?? olarak kullan??lamaz, 
					           |ancak eri??im t??r??n??n a????klamas??nda %2 bulunabilir.';
					           |it = 'Il tipo di proprietario dei diritti ""%1""
					           |non pu?? essere usato come un tipo di valore di accesso
					           |ma ?? stato rilevato nella descrizione del tipo di accesso ""%2"".';
					           |de = 'Der Typ des Rechteinhabers ""%1""
					           |kann nicht als Wert f??r die Art des Zugriffs verwendet werden, er ist
					           |jedoch in der Beschreibung der Art des Zugriffs ""%2"" enthalten.'"),
					String(RefType),
					AccessKindsProperties.ByValuesTypes.Get(RefType).Name);
			EndIf;
			
			If AccessKindsProperties.ByGroupsAndValuesTypes.Get(RefType) <> Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '?????? ?????????????????? ???????? ""%1""
					           |???? ?????????? ????????????????????????????, ?????? ?????? ?????????? ???????????????? ??????????????,
					           |???? ?????????????????? ?? ???????????????? ???????? ?????????????? ""%2"".'; 
					           |en = '""%1"" rights owner type
					           |cannot be used as a type of access value groups but 
					           |it is detected in description of access kind ""%2"".'; 
					           |pl = 'Typ posiadacza praw ""%1""
					           |nie mo??e by?? u??ywany, jako typ grup warto??ci dost??pu,
					           |ale znajduje si?? w opisie typu dost??pu ""%2""';
					           |es_ES = 'El tipo del propietario de derechos ""%1""
					           |no puede ser usado como el tipo de grupos de valores de acceso,
					           |pero se ha encontrado en el tipo de acceso ""%2"".';
					           |es_CO = 'El tipo del propietario de derechos ""%1""
					           |no puede ser usado como el tipo de grupos de valores de acceso,
					           |pero se ha encontrado en el tipo de acceso ""%2"".';
					           |tr = 'Hak sahibinin t??r??, 
					           | %1 eri??im de??eri gruplar??n??n t??r?? olarak kullan??lamaz, 
					           |ancak eri??im t??r??n??n a????klamas??nda %2 bulunabilir.';
					           |it = 'Il tipo di proprietario dei diritti ""%1""
					           |non pu?? essere usato come un tipo di gruppi di valori di accesso
					           |ma ?? stato rilevato nella descrizione del tipo di accesso ""%2"".';
					           |de = 'Der Typ des Rechteinhabers ""%1""
					           |kann nicht als Typ von Zugriffswertegruppen verwendet werden,
					           |sondern ist in der Beschreibung der Zugriffsart ""%2"" zu finden.'"),
					String(RefType),
					AccessKindsProperties.ByValuesTypes.Get(RefType).Name);
			EndIf;
			
			If SubscriptionTypesUpdateRightsSettingsOwnersGroups.Get(ObjectType) = Undefined Then
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '?????? ?????????????????? ???????? ""%1""
					           |???? ???????????? ?? ???????????????????????? ???????? ""???????????????? ???????????????? ???????? ????????????"".'; 
					           |en = '""%1"" rights owner type
					           |is not specified in defined type ""Owner of object rights settings"".'; 
					           |pl = 'Typ w??a??ciciela praw ""%1""
					           |nie jest okre??lony w podym typie ""W??a??ciciel ustawie?? praw obiekt"".';
					           |es_ES = 'El tipo del propietario de derechos ""%1""
					           |no se ha indicado en el tipo ""Propietario de ajustes de derechos objeto"".';
					           |es_CO = 'El tipo del propietario de derechos ""%1""
					           |no se ha indicado en el tipo ""Propietario de ajustes de derechos objeto"".';
					           |tr = 'Hak sahibinin t??r??"
" %1 ""Hak ayarlar?? sahibi nesne"" tan??mlanm???? t??r??nde belirtilmemi??.';
					           |it = 'Il tipo di proprietario dei diritti ""%1"" 
					           |non ?? indicato nel tipo definito ""Proprietario delle impostazioni dei diritti dell''oggetto"".';
					           |de = 'Der Typ des Eigent??mers der Rechte ""%1""
					           |ist im bezeichneten Typ ""Eigent??mer der Einstellungen der Rechte des Objekts"" nicht angegeben.'"),
					String(ObjectType));
			EndIf;
			
			ByFullNames.Insert(PossibleRight.RightsOwner, OwnerRights);
			ByRefsTypes.Insert(RefType,  OwnerRightsArray);
			ByTypes.Insert(RefType,  OwnerRights);
			ByTypes.Insert(ObjectType, OwnerRights);
			If HierarchicalMetadataObject(OwnerMetadataObject) Then
				HierarchicalTables.Insert(RefType,  True);
				HierarchicalTables.Insert(ObjectType, True);
			EndIf;
			
			OwnersTypes.Add(Common.ObjectManagerByFullName(
				PossibleRight.RightsOwner).EmptyRef());
				
			OwnersRightsIndexes.Insert(PossibleRight.RightsOwner, 0);
		EndIf;
		
		If OwnerRights.Get(PossibleRight.Name) <> Undefined Then
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '?????? ?????????????????? ???????? ""%1""
				           |???????????????? ???????????????????? ?????????? ""%2"".'; 
				           |en = 'The ""%2"" right 
				           |is defined again for the ""%1"" right owner.'; 
				           |pl = 'W przypadku w??a??ciciela praw ""%1""
				           |prawo to na nowo zdefiniowane ""%2"".';
				           |es_ES = 'Para el propietario de derechos ""%1""
				           |, el derecho ""%2"" est?? definido una vez m??s.';
				           |es_CO = 'Para el propietario de derechos ""%1""
				           |, el derecho ""%2"" est?? definido una vez m??s.';
				           |tr = 'Hak sahibi i??in %1
				           |hak yeniden %2 tan??mland??.';
				           |it = 'Il diritto ""%2"" ?? 
				           |definito di nuovo per il proprietario dei diritti ""%1"".';
				           |de = 'F??r den Rechteinhaber ""%1""
				           |wird das Recht neu definiert ""%2"".'"),
				PossibleRight.RightsOwner,
				PossibleRight.Name);
		EndIf;
		
		// Converting the list of required rights to arrays.
		Separator = "|";
		For Index = 0 To PossibleRight.RequiredRights.Count()-1 Do
			If StrFind(PossibleRight.RequiredRights[Index], Separator) > 0 Then
				PossibleRight.RequiredRights[Index] = StrSplit(
					PossibleRight.RequiredRights[Index], Separator, False);
			EndIf;
		EndDo;
		
		PossibleRightProperties = New Structure(
			"RightsOwner,
			|Name,
			|Title,
			|ToolTip,
			|InitialValue,
			|RequiredRights,
			|ReadInTables,
			|ChangeInTables,
			|RightIndex");
		FillPropertyValues(PossibleRightProperties, PossibleRight);
		PossibleRightProperties.RightIndex = OwnersRightsIndexes[PossibleRight.RightsOwner];
		OwnersRightsIndexes[PossibleRight.RightsOwner] = PossibleRightProperties.RightIndex + 1;
		
		OwnerRights.Insert(PossibleRight.Name, PossibleRightProperties);
		OwnerRightsArray.Add(PossibleRightProperties);
	EndDo;
	
	// Adding individual tables.
	CommonTable = Catalogs.MetadataObjectIDs.EmptyRef();
	For each RightsDetails In ByFullNames Do
		SeparateRights = AdditionalParameters.IndividualOwnersRights.Get(RightsDetails.Key);
		For each RightDetails In RightsDetails.Value Do
			RightProperties = RightDetails.Value;
			If RightProperties.ChangeInTables.Find(CommonTable) <> Undefined Then
				For each KeyAndValue In SeparateTables Do
					SeparateTable = KeyAndValue.Key;
					
					If SeparateRights.ChangeInTables[SeparateTable] = Undefined
					   AND RightProperties.ChangeInTables.Find(SeparateTable) = Undefined Then
					
						RightProperties.ChangeInTables.Add(SeparateTable);
					EndIf;
				EndDo;
			EndIf;
		EndDo;
	EndDo;
	
	AvailableRights = New Structure;
	AvailableRights.Insert("ByTypes",                       ByTypes);
	AvailableRights.Insert("ByRefsTypes",                 ByRefsTypes);
	AvailableRights.Insert("ByFullNames",                ByFullNames);
	AvailableRights.Insert("OwnersTypes",                OwnersTypes);
	AvailableRights.Insert("SeparateTables",              SeparateTables);
	AvailableRights.Insert("HierarchicalTables",          HierarchicalTables);
	
	Return Common.FixedData(AvailableRights);
	
EndFunction

Procedure FillIDs(Property, PossibleRight, ErrorTitle, SeparateTables, AdditionalParameters)
	
	If AdditionalParameters.CommonOwnersRights.Get(AdditionalParameters.RightsOwner) = Undefined Then
		CommonRights     = New Structure("ReadInTables, ChangeInTables", "", "");
		SeparateRights = New Structure("ReadInTables, ChangeInTables", New Map, New Map);
		
		AdditionalParameters.CommonOwnersRights.Insert(AdditionalParameters.RightsOwner, CommonRights);
		AdditionalParameters.IndividualOwnersRights.Insert(AdditionalParameters.RightsOwner, SeparateRights);
	Else
		CommonRights     = AdditionalParameters.CommonOwnersRights.Get(AdditionalParameters.RightsOwner);
		SeparateRights = AdditionalParameters.IndividualOwnersRights.Get(AdditionalParameters.RightsOwner);
	EndIf;
	
	Array = New Array;
	
	For each Value In PossibleRight[Property] Do
		
		If Value = "*" Then
			If PossibleRight[Property].Count() <> 1 Then
				
				If Property = "ReadInTables" Then
					ErrorDescription =
						NStr("ru = '?????? ?????????????????? ???????? ""%1""
						           |?????? ?????????? ""%2"" ?? ???????????????? ?????? ???????????? ???????????? ???????????? ""*"".
						           |?? ???????? ???????????? ?????????????????? ???????????? ?????????????????? ???? ??????????.'; 
						           |en = 'An asterisk (""*"") is specified for the ""%1""
						           |right owner for the ""%2"" right in tables for reading.
						           |In this case, do not specify separate tables.'; 
						           |pl = 'Dla w??a??ciciela praw ""%1""
						           |dla prawa ""%2"" w tabelach do czytania wy??wietlany jest symbol ""*"".
						           |W tym przypadku nie trzeba podawa?? poszczeg??lnych tabel.';
						           |es_ES = 'Para el propietario de derechos ""%1""
						           |para el derecho ""%2"" en las tablas para leer est?? indicado el s??mbolo ""*"".
						           |En este caso no hay que indicar tablas separadas.';
						           |es_CO = 'Para el propietario de derechos ""%1""
						           |para el derecho ""%2"" en las tablas para leer est?? indicado el s??mbolo ""*"".
						           |En este caso no hay que indicar tablas separadas.';
						           |tr = 'Okuma i??in tablolarda hak sahibi i??in ""*"" 
						           |karakteri belirtilmi??tir. %1Bu durumda %2 ayr?? tablolar 
						           |belirtilmemelidir.';
						           |it = 'Per il proprietario dei diritti ""%1""
						           | ?? specificato l''asterisco (""*"") per il diritto ""%2"" nelle tabelle di lettura.
						           |In questo caso non serve specificare tabelle separate.';
						           |de = 'F??r den Inhaber der Rechte ""%1""
						           |f??r das Recht ""%2"" in den Tabellen zum Lesen ist das Symbol ""*"" angegeben.
						           |In diesem Fall ist es nicht erforderlich, einzelne Tabellen anzugeben.'")
				Else
					ErrorDescription =
						NStr("ru = '?????? ?????????????????? ???????? ""%1""
						           |?????? ?????????? ""%2"" ?? ???????????????? ?????? ?????????????????? ???????????? ???????????? ""*"".
						           |?? ???????? ???????????? ?????????????????? ???????????? ?????????????????? ???? ??????????.'; 
						           |en = 'An asterisk (""*"") is specified
						           |for the ""%1"" right owner for the ""%2"" right in tables for change.
						           |In this case, do not specify separate tables.'; 
						           |pl = 'Dla w??a??ciciela praw ""%1""
						           |dla prawa ""%2"" w tabelach do zmiany wy??wietlany jest symbol ""*"".
						           |W tym przypadku nie trzeba podawa?? poszczeg??lnych tabel.';
						           |es_ES = 'Para el propietario de derechos ""%1""
						           |para el derecho ""%2"" en las tablas para cambiar est?? indicado el s??mbolo ""*"".
						           |En este caso no hay que indicar tablas separadas.';
						           |es_CO = 'Para el propietario de derechos ""%1""
						           |para el derecho ""%2"" en las tablas para cambiar est?? indicado el s??mbolo ""*"".
						           |En este caso no hay que indicar tablas separadas.';
						           |tr = 'De??i??en tablolarda %1 hak sahibi i??in ""*""
						           |karakteri belirtilmi??tir %2 Bu durumda ayr?? tablolar belirtilmemelidir
						           |';
						           |it = 'Per il proprietario dei diritti ""%1"" ??
						           |specificato l''asterisco (""*"") per il diritto ""%2"" nelle tabelle da modificare.
						           |In questo caso non serve specificare tabelle separate.';
						           |de = 'F??r den Inhaber der Rechte ""%1""
						           |f??r das Recht ""%2"" in den Tabellen zur ??nderung ist das Symbol ""*"" angegeben.
						           |In diesem Fall ist es nicht erforderlich, einzelne Tabellen anzugeben.'")
				EndIf;
				
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					ErrorDescription, AdditionalParameters.RightsOwner, PossibleRight.Name);
			EndIf;
			
			If ValueIsFilled(CommonRights[Property]) Then
				
				If Property = "ReadInTables" Then
					ErrorDescription =
						NStr("ru = '?????? ?????????????????? ???????? ""%1""
						           |?????? ?????????? ""%2"" ?? ???????????????? ?????? ???????????? ???????????? ???????????? ""*"".
						           |???????????? ???????????? ""*"" ?????? ???????????? ?? ???????????????? ?????? ???????????? ?????? ?????????? ""%3"".'; 
						           |en = 'An asterisk (""*"") is specified 
						           |for the ""%1"" right owner for the ""%2"" right in tables for reading.
						           |The asterisk is already specified in tables for reading for the ""%3"" right.'; 
						           |pl = 'Dla w??a??ciciela praw ""%1""
						           |dla prawa ""%2"" w tabelach do czytania wy??wietlany jest symbol ""*"".
						           |W tym przypadku nie trzeba podawa?? w tabelach do czytania dla prawa ""%3"".';
						           |es_ES = 'Para el propietario de derechos ""%1""
						           |para el derecho ""%2"" en las tablas para leer est?? indicado el s??mbolo ""*"".
						           |Pero el s??mbolo ""*"" ya se ha indicado en las tablas para leer para el derecho ""%3"".';
						           |es_CO = 'Para el propietario de derechos ""%1""
						           |para el derecho ""%2"" en las tablas para leer est?? indicado el s??mbolo ""*"".
						           |Pero el s??mbolo ""*"" ya se ha indicado en las tablas para leer para el derecho ""%3"".';
						           |tr = 'Okuma i??in tablolarda hak sahibi i??in ""*"" 
						           |karakteri belirtilmi??tir. %1Ancak, * karakteri, %2 hakk?? i??in okuma tablolar??nda 
						           |zaten belirtilmi??tir.%3';
						           |it = 'Per il proprietario dei diritti ""%1"" ??
						           |specificato l''asterisco (""*"") per il diritto ""%2"" nelle tabelle di lettura.
						           |L''asterisco ?? gi?? specificato nelle tabelle di lettura per il diritto ""%3"".';
						           |de = 'F??r den Inhaber der Rechte ""%1""
						           |f??r das Recht ""%2"" in den Tabellen zum Lesen ist das Symbol ""*"" angegeben.
						           |Das Symbol ""*"" ist jedoch bereits in den Tabellen zum Lesen f??r das Recht ""%3"" angegeben.'")
				Else
					ErrorDescription =
						NStr("ru = '?????? ?????????????????? ???????? ""%1""
						           |?????? ?????????? ""%2"" ?? ???????????????? ?????? ?????????????????? ???????????? ???????????? ""*"".
						           |???????????? ???????????? ""*"" ?????? ???????????? ?? ???????????????? ?????? ?????????????????? ?????? ?????????? ""%3"".'; 
						           |en = 'An asterisk (""*"") is specified 
						           |for the ""%1"" right owner for the ""%2"" right in tables for change.
						           |The asterisk is already specified in tables for changes for the ""%3"" right.'; 
						           |pl = 'Dla w??a??ciciela praw ""%1""
						           |dla prawa ""%2"" w tabelach do zmian wy??wietlany jest symbol ""*"".
						           |W tym przypadku nie trzeba podawa?? w tabelach do zmian dla prawa ""%3"".';
						           |es_ES = 'Para el propietario de derechos ""%1""
						           |para el derecho ""%2"" en las tablas para cambiar est?? indicado el s??mbolo ""*"".
						           |Pero el s??mbolo ""*"" ya se ha indicado en las tablas para cambiar para el derecho ""%3"".';
						           |es_CO = 'Para el propietario de derechos ""%1""
						           |para el derecho ""%2"" en las tablas para cambiar est?? indicado el s??mbolo ""*"".
						           |Pero el s??mbolo ""*"" ya se ha indicado en las tablas para cambiar para el derecho ""%3"".';
						           |tr = 'De??i??en tablolarda hak sahibi i??in ""*"" 
						           |karakteri belirtilmi??tir. %1Ancak, ""*"" karakteri %2 sa??a do??ru de??i??tirmek 
						           |i??in tablolarda zaten belirtilmi??tir.%3';
						           |it = 'Per il proprietario dei diritti ""%1"" ??
						           |specificato l''asterisco (""*"") per il diritto ""%2"" nelle tabelle da modificare.
						           |L''asterisco ?? gi?? specificato nelle tabelle da modificare per il diritto ""%3"".';
						           |de = 'F??r den Inhaber der Rechte ""%1""
						           |f??r das Recht ""%2"" in den Tabellen zur ??nderung ist das Symbol ""*"" angegeben.
						           |Das Symbol ""*"" ist jedoch bereits in den Tabellen zur ??nderung f??r das Recht ""%3"" angegeben.'")
				EndIf;
				
				Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription,
					AdditionalParameters.RightsOwner, PossibleRight.Name, CommonRights[Property]);
			Else
				CommonRights[Property] = PossibleRight.Name;
			EndIf;
			
			Array.Add(Catalogs.MetadataObjectIDs.EmptyRef());
			
		ElsIf Property = "ReadInTables" Then
			ErrorDescription =
				NStr("ru = '?????? ?????????????????? ???????? ""%1""
				           |?????? ?????????? ""%2"" ?????????????? ???????????????????? ?????????????? ?????? ???????????? ""%3"".
				           |???????????? ?????? ???? ?????????? ????????????, ??.??. ?????????? ???????????? ?????????? ???????????????? ???????????? ???? ?????????? ????????????.
				           |?????????? ?????????? ???????????????????????? ???????????? ???????????? ""*"".'; 
				           |en = 'Specific table ""%3""
				           |for reading is specified for the ""%1"" right owner for the ""%2"" right.
				           |It does not make sense, as the Read right depends only on the Read right.
				           |Only using an asterisk (""*"") makes sense.'; 
				           |pl = 'Dla posiadacza praw %1
				           | dla prawa %2 okre??lono konkretn?? tablic?? do odczytu %3. 
				           |Jednak??e nie ma to sensu, poniewa?? prawo Odczyt mo??e zale??e?? wy????cznie od prawa Odczyt
				           |. Ma sens u??ywanie tylko znaku *.';
				           |es_ES = 'Para el propietario de derechos %1
				           | para el derecho %2, la tabla especificada para lectura %3 est?? especificada.
				           |Sin embargo, no tiene sentido como el derecho de Lectura puede depender solo del derecho de Lectura
				           |Tiene sentido utilizar solo el s??mbolo *.';
				           |es_CO = 'Para el propietario de derechos %1
				           | para el derecho %2, la tabla especificada para lectura %3 est?? especificada.
				           |Sin embargo, no tiene sentido como el derecho de Lectura puede depender solo del derecho de Lectura
				           |Tiene sentido utilizar solo el s??mbolo *.';
				           |tr = 'Hak sahibinin %1 hak sahibi i??in, belirtilen okuma tablosu belirtilir.
				           | Bununla birlikte,%2 Okuma Hakk?? sadece%3 Okuma hakk??na ba??l?? olabilece??inden hi??bir anlam ifade etmez.
				           | Sadece
				           | * karakterini kullanmak mant??kl??d??r.';
				           |it = 'La tabella specifica di lettura ""%3""
				           |?? indicata per il proprietario dei diritti ""%1"" per il diritto ""%2"".
				           |Ci?? non ha senso, poich?? il Diritto di lettura dipende solo dal Diritto di lettura.
				           | Avrebbe senso solo l''uso di un asterisco (""*"").';
				           |de = 'F??r den %1
				           |Rechteinhaber f??r %2Recht wird die angegebene Tabelle zum Lesen %3 angegeben.
				           |Es macht jedoch keinen Sinn, da das Leserecht nur vom Leserecht
				           |abh??ngen kann. Es ist sinnvoll, nur das Zeichen ""*"" zu verwenden.'");
				
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription,
				AdditionalParameters.RightsOwner, PossibleRight.Name, Value);
			
		ElsIf Metadata.FindByFullName(Value) = Undefined Then
			
			If Property = "ReadInTables" Then
				ErrorDescription = NStr("ru = '?????? ?????????????????? ???????? ""%1""
				                            |?????? ?????????? ""%2"" ???? ?????????????? ?????????????? ?????? ???????????? ""%3"".'; 
				                            |en = 'Table for reading ""%3""
				                            |is not found for the ""%1"" right owner for the ""%2"" right.'; 
				                            |pl = 'Dla w??a??ciciela praw ""%1""
				                            |dla prawa ""%2"" tabela do czytania nie zosta??a znaleziona ""%3"".';
				                            |es_ES = 'Para el propietario de derechos ""%1""
				                            |para el derecho ""%2"", la tabla de leer ""%3"" no se ha encontrado.';
				                            |es_CO = 'Para el propietario de derechos ""%1""
				                            |para el derecho ""%2"", la tabla de leer ""%3"" no se ha encontrado.';
				                            |tr = '%1
				                            |Hak sahibi i??in %2 hak i??in okuma tablosu %3 bulunamad??.';
				                            |it = 'Tabella di lettura ""%3""
				                            |non trovata per il proprietario dei diritti ""%1"" per il diritto ""%2"".';
				                            |de = 'F??r den Rechteinhaber ""%1""
				                            |f??r das Recht ""%2"" wurde die Tabelle zum Lesen ""%3"" nicht gefunden.'")
			Else
				ErrorDescription = NStr("ru = '?????? ?????????????????? ???????? ""%1""
				                            |?????? ?????????? ""%2"" ???? ?????????????? ?????????????? ?????? ?????????????????? ""%3"".'; 
				                            |en = 'Table for change ""%3""
				                            |is not found for the ""%1"" right owner for the ""%2"" right.'; 
				                            |pl = 'Dla w??a??ciciela praw ""%1""
				                            |dla prawa ""%2"" tabela do zmian nie zosta??a znaleziona %3"".';
				                            |es_ES = 'Para el propietario de derechos ""%1""
				                            |para el derecho ""%2"", la tabla de cambiar ""%3"" no se ha encontrado.';
				                            |es_CO = 'Para el propietario de derechos ""%1""
				                            |para el derecho ""%2"", la tabla de cambiar ""%3"" no se ha encontrado.';
				                            |tr = '%1
				                            |Hak sahibi i??in %2 hak i??in de??i??iklik tablosu %3 bulunamad??.';
				                            |it = 'Tabella da modificare ""%3""
				                            |non trovata per il proprietario dei diritti ""%1"" per il diritto ""%2"".';
				                            |de = 'F??r den Rechteinhaber ""%1""
				                            |f??r das Recht ""%2"" wurde die Tabelle zum ??ndern von ""%3"" nicht gefunden.'")
			EndIf;
			
			Raise ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription,
				AdditionalParameters.RightsOwner, PossibleRight.Name, Value);
		Else
			TableID = Common.MetadataObjectID(Value);
			Array.Add(TableID);
			
			SeparateTables.Insert(TableID, Value);
			SeparateRights[Property].Insert(TableID, PossibleRight.Name);
		EndIf;
		
	EndDo;
	
	PossibleRight[Property] = Array;
	
EndProcedure

Function HierarchicalMetadataObject(MetadataObjectDetails)
	
	If TypeOf(MetadataObjectDetails) = Type("String") Then
		MetadataObject = Metadata.FindByFullName(MetadataObjectDetails);
	ElsIf TypeOf(MetadataObjectDetails) = Type("Type") Then
		MetadataObject = Metadata.FindByType(MetadataObjectDetails);
	Else
		MetadataObject = MetadataObjectDetails;
	EndIf;
	
	If TypeOf(MetadataObject) <> Type("MetadataObject") Then
		Return False;
	EndIf;
	
	If NOT Metadata.Catalogs.Contains(MetadataObject)
	   AND NOT Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject) Then
		
		Return False;
	EndIf;
	
	Return MetadataObject.Hierarchical;
	
EndFunction

#EndRegion

#EndIf
