#Region Internal

// Returns names and roles synonyms.
//
Function AllRoles() Export
	
	Array = New Array;
	Map = New Map;
	
	Table = New ValueTable;
	Table.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(256)));
	
	For each Role In Metadata.Roles Do
		RoleName = Role.Name;
		
		Array.Add(RoleName);
		Map.Insert(RoleName, Role.Synonym);
		Table.Add().Name = RoleName;
	EndDo;
	
	AllRoles = New Structure;
	AllRoles.Insert("Array",       New FixedArray(Array));
	AllRoles.Insert("Map", New FixedMap(Map));
	AllRoles.Insert("Table",      New ValueStorage(Table));
	
	Return Common.FixedData(AllRoles, False);
	
EndFunction

// Returns roles unavailable for the specified assignment (with or without SaaS mode).
//
// Parameters:
//  Purpose - String - "ForAdministrators", "ForUsers", "ForExternalUsers", and
//                        "BothForUsersAndExternalUsers".
//     
//  Service - Undeifned - determine the current mode automatically.
//             - Boolean - False - for a local mode (unavailable roles only for assignment),
//                              True - for SaaS mode (including the roles of shared users).
//
// Returns:
//  Map with the following properties:
//   * Key - String - role name.
//   * Value - Boolean - True.
//
Function UnavailableRoles(Assignment = "ForUsers", Service = Undefined) Export
	
	CheckAssignment(Assignment,
		NStr("ru = 'Ошибка в функции UnavailableRoles общего модуля UsersInternalCached.'; en = 'Error in UnavailableRoles function of UsersInternalCached common module.'; pl = 'Błąd w funkcji UnavailableRoles modułu ogólnego UsersInternalCached.';es_ES = 'Error en la función UnavailableRoles del módulo común UsersInternalCached.';es_CO = 'Error en la función UnavailableRoles del módulo común UsersInternalCached.';tr = 'UsersInternalCached ortak modülünün UnavailableRoles fonksiyonunda hata.';it = 'Errore nella funzione UnavailableRoles del modulo generale UsersInternalCached.';de = 'Fehler in der Funktion NichtZugänglicheRollen des allgemeinen Moduls BenutzerService WiederhNutzung.'"));
	
	If Service = Undefined Then
		Service = Common.DataSeparationEnabled();
	EndIf;
	
	RolesAssignment = UsersInternalCached.RolesAssignment();
	UnavailableRoles = New Map;
	
	For Each Role In Metadata.Roles Do
		If (Assignment <> "ForAdministrators" Or Service)
		   AND RolesAssignment.ForSystemAdministratorsOnly.Get(Role.Name) <> Undefined
		 // For external users.
		 Or Assignment = "ForExternalUsers"
		   AND RolesAssignment.ForExternalUsersOnly.Get(Role.Name) = Undefined
		   AND RolesAssignment.BothForUsersAndExternalUsers.Get(Role.Name) = Undefined
		 // For users.
		 Or (Assignment = "ForUsers" Or Assignment = "ForAdministrators")
		   AND RolesAssignment.ForExternalUsersOnly.Get(Role.Name) <> Undefined
		 // Shared by users and external users.
		 Or Assignment = "BothForUsersAndExternalUsers"
		   AND Not RolesAssignment.BothForUsersAndExternalUsers.Get(Role.Name) <> Undefined
		 // With SaaS mode.
		 Or Service
		   AND RolesAssignment.ForSystemUsersOnly.Get(Role.Name) <> Undefined Then
			
			UnavailableRoles.Insert(Role.Name, True);
		EndIf;
	EndDo;
	
	Return New FixedMap(UnavailableRoles);
	
EndFunction

// Returns unavailable roles for shared users or external users based on the rights of the current 
// user and the operation mode (local or SaaS mode).
//
// Parameters:
//  ForExternalUsers - Boolean - if true, then for external user.
//
// Returns:
//  Map with the following properties:
//   * Key - String - role name.
//   * Value - Boolean - True.
//
Function UnavailableRolesByUserType(ForExternalUsers) Export
	
	If ForExternalUsers Then
		UserRolesAssignment = "ForExternalUsers";
		
	ElsIf Not Common.DataSeparationEnabled()
	        AND Users.IsFullUser(, True, False) Then
		
		// A user with the FullAdministrator role in local mode can issue administrative rights.
		// 
		UserRolesAssignment = "ForAdministrators";
	Else
		UserRolesAssignment = "ForUsers";
	EndIf;
	
	Return UsersInternalCached.UnavailableRoles(UserRolesAssignment);
	
EndFunction

#EndRegion

#Region Private

// Returns the role assignment defined by the developer.
// See comment to the OnDetermineRoleAssignment procedure of the UsersOverridable common module.
//
// Returns:
//  FixedStructure - with the following properties:
//   * ForSystemAdministratorsOnly - FixedMap - with the following properties:
//      * Key - String - role name.
//      * Value - Boolean - True.
//   * ForSystemUsersOnly - FixedMap - with the following properties:
//      * Key - String - role name.
//      * Value - Boolean - True.
//   * ForExternalUsersOnly - FixedMap - with the following properties:
//      * Key - String - role name.
//      * Value - Boolean - True.
//   * BothForUsersAndExternalUsers - FixedMap - with the following properties:
//      * Key - String - role name.
//      * Value - Boolean - True.
//
Function RolesAssignment() Export
	
	RolesAssignment = Users.RolesAssignment();
	
	Assignment = New Structure;
	For Each RolesAssignmentDetails In RolesAssignment Do
		Names = New Map;
		For Each Name In RolesAssignmentDetails.Value Do
			Names.Insert(Name, True);
		EndDo;
		Assignment.Insert(RolesAssignmentDetails.Key, New FixedMap(Names));
	EndDo;
	
	Return New FixedStructure(Assignment);
	
EndFunction

// See UsersClientServer.IsExternalUserSession. 
Function IsExternalUserSession() Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS") Then
		ModuleSaaS = Common.CommonModule("SaaS");
		SessionWithoutSeparators = ModuleSaaS.SessionWithoutSeparators();
	Else
		SessionWithoutSeparators = True;
	EndIf;
	
	If Common.DataSeparationEnabled()
	   AND SessionWithoutSeparators Then
		// Shared users cannot be external users.
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	
	InfobaseUser = InfoBaseUsers.CurrentUser();
	IBUserID = InfobaseUser.UUID;
	
	Users.FindAmbiguousIBUsers(Undefined, IBUserID);
	
	Query = New Query;
	Query.SetParameter("IBUserID", IBUserID);
	
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.IBUserID = &IBUserID";
	
	// A user who is not found in the ExternalUsers catalog cannot be external.
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Settings of the Users subsystem operation.
// See the deatails of the OnDetermineSettings procedure in the UsersOverridable common module
//
// Returns:
//  Structure - with the following properties:
//   * CommonAuthorizationSettings - Boolean - if False, the option to open the authorization 
//          settings form is hidden from the "Users and rights settings" administration panel, as 
//          well as the ValidityPeriod field in profiles of users and external users.
//          
//
//   * EditRoles - Boolean - if False, hide the role editing interface from profiles of users, 
//          external users, and groups of external users. This affects both regular users and 
//          administrators.
//
//   * ExternalUsers - Structure - with the same properties as the User properties (see further).
//   * Users - Structure - with the following properties:
//
//     * PasswordMustMeetComplexityRequirements - Boolean - check the complexity of a new password.
//     * MinimumPasswordLength - Number - check the length of a new password.
//
//     * MaxPasswordLifetime             - the period from the first use of the password to the 
//                                                            moment the password expires.
//     * MinPasswordLifetime              - the period when a user cannot change the password, 
//                                                            beginning from the period from the first use of the password.
//     * DenyReusingRecentPasswords - Number - number of passwords, hashes of which will be stored for checking.
//
//     * InactivityPeriodBeforeDenyingAuthorization - Number - a number of days since the latest 
//                                                            activity of the user, after which the authorization will be denied.
//     * InactivityPeriodActivationDate - Sate - a date of recording a non-zero number of inactive 
//                                                            days instead of zero.
//
Function Settings() Export
	
	Settings = New Structure;
	Settings.Insert("CommonAuthorizationSettings", True);
	Settings.Insert("EditRoles", True);
	
	SSLSubsystemsIntegration.OnDefineSettings(Settings);
	UsersOverridable.OnDefineSettings(Settings);
	
	If Common.DataSeparationEnabled()
	 Or StandardSubsystemsServer.IsBaseConfigurationVersion()
	 Or Common.IsStandaloneWorkplace() Then
		
		Settings.Insert("CommonAuthorizationSettings", False);
	EndIf;
	
	AllSettings = UsersInternal.AuthorizationSettings();
	AllSettings.Insert("CommonAuthorizationSettings", Settings.CommonAuthorizationSettings);
	AllSettings.Insert("EditRoles", Settings.EditRoles);
	
	Return Common.FixedData(AllSettings);
	
EndFunction

// Returns a tree of roles (with the option to group roles by subsystem).
// If a role is not included in any subsystem, it is added to the root.
// 
// Parameters:
//  BySubsystems - Boolean, if False, all roles are added to the root.
//  Purpose - String - "ForAdministrator", "ForUsers", "ForExternalUsers",
//                           "BothForUsersAndExternalUsers".
// 
// Returns:
//  ValueTree with the following columns:
//    IsRole - Boolean
//    Name - String - name of a role or a subsystem.
//    Synonym - String - a synonym of a role or a subsystem.
//
Function RoleTree(BySubsystems = True, Assignment = "ForUsers") Export
	
	CheckAssignment(Assignment,
		NStr("ru = 'Ошибка в функции RoleTree общего модуля UsersInternalCached.'; en = 'Error in RoleTree function of UsersInternalCached common module.'; pl = 'Błąd w funkcji RoleTree UsersInternalCached ogólnego modułu.';es_ES = 'Error en la función RoleTree del módulo UsersInternalCached.';es_CO = 'Error en la función RoleTree del módulo UsersInternalCached.';tr = 'UsersInternalCached ortak modülünün RoleTree fonksiyonunda hata.';it = 'Errore nella funzione RoleTree del modulo generale UsersInternalCached.';de = 'Fehler in der Funktion BaumRolle des allgemeinen Moduls BenutzerService WiederhNutzung.'"));
	
	UnavailableRoles = UsersInternalCached.UnavailableRoles(Assignment);
	
	Tree = New ValueTree;
	Tree.Columns.Add("IsRole", New TypeDescription("Boolean"));
	Tree.Columns.Add("Name",     New TypeDescription("String"));
	Tree.Columns.Add("Synonym", New TypeDescription("String", , New StringQualifiers(1000)));
	
	If BySubsystems Then
		FillSubsystemsAndRoles(Tree.Rows, , UnavailableRoles);
	EndIf;
	
	// Adding roles that are not found.
	For Each Role In Metadata.Roles Do
		
		If UnavailableRoles.Get(Role.Name) <> Undefined
		 Or Upper(Left(Role.Name, StrLen("Delete"))) = Upper("Delete") Then
			
			Continue;
		EndIf;
		
		Filter = New Structure("IsRole, Name", True, Role.Name);
		If Tree.Rows.FindRows(Filter, True).Count() = 0 Then
			TreeRow = Tree.Rows.Add();
			TreeRow.IsRole       = True;
			TreeRow.Name           = Role.Name;
			TreeRow.Synonym       = ?(ValueIsFilled(Role.Synonym), Role.Synonym, Role.Name);
		EndIf;
	EndDo;
	
	Tree.Rows.Sort("IsRole Desc, Synonym Asc", True);
	
	Return New ValueStorage(Tree);
	
EndFunction

// See Users.CheckedIBUserProperties. 
Function CurrentIBUserProperties() Export
	
	InfobaseUser = InfoBaseUsers.CurrentUser();
	
	Properties = New Structure;
	Properties.Insert("IsCurrentIBUser", True);
	Properties.Insert("UUID", InfobaseUser.UUID);
	Properties.Insert("Name",                     InfobaseUser.Name);
	
	Properties.Insert("AdministrationRight", ?(PrivilegedMode(),
		AccessRight("Administration", Metadata, InfobaseUser),
		AccessRight("Administration", Metadata)));
	
	Properties.Insert("SystemAdministratorRoleAvailable",
		IsInRole(Metadata.Roles.SystemAdministrator)); // Do not change to RolesAvailable.
	
	Properties.Insert("RoleAvailableFullAccess",
		IsInRole(Metadata.Roles.FullRights)); // Do not change to RolesAvailable.
	
	Return New FixedStructure(Properties);
	
EndFunction

// Returns empty references of the types of authorization objects specified in the ExternalUser 
// defined type.
//
// If the String type or other non-node types are specified in the defined type, it is ignored.
// 
//
// Returns:
//  FixedArray - array of the following values:
//   * Value - Reference - an empty reference of an authorization object type.
//
Function BlankRefsOfAuthorizationObjectTypes() Export
	
	BlankRefs = New Array;
	
	For Each Type In Metadata.DefinedTypes.ExternalUser.Type.Types() Do
		If Not Common.IsReference(Type) Then
			Continue;
		EndIf;
		RefTypeDetails = New TypeDescription(CommonClientServer.ValueInArray(Type));
		BlankRefs.Add(RefTypeDetails.AdjustValue(Undefined));
	EndDo;
	
	Return New FixedArray(BlankRefs);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Procedure FillSubsystemsAndRoles(TreeRowCollection, Subsystems, UnavailableRoles, AllRoles = Undefined)
	
	If Subsystems = Undefined Then
		Subsystems = Metadata.Subsystems;
	EndIf;
	
	If AllRoles = Undefined Then
		AllRoles = New Map;
		For Each Role In Metadata.Roles Do
			
			If UnavailableRoles.Get(Role.Name) <> Undefined
			 Or Upper(Left(Role.Name, StrLen("Delete"))) = Upper("Delete") Then
			
				Continue;
			EndIf;
			AllRoles.Insert(Role, True);
		EndDo;
	EndIf;
	
	For Each Subsystem In Subsystems Do
		
		SubsystemDetails = TreeRowCollection.Add();
		SubsystemDetails.Name     = Subsystem.Name;
		SubsystemDetails.Synonym = ?(ValueIsFilled(Subsystem.Synonym), Subsystem.Synonym, Subsystem.Name);
		
		FillSubsystemsAndRoles(SubsystemDetails.Rows, Subsystem.Subsystems, UnavailableRoles, AllRoles);
		
		For Each MetadataObject In Subsystem.Content Do
			If AllRoles[MetadataObject] = Undefined Then
				Continue;
			EndIf;
			Role = MetadataObject;
			RoleDetails = SubsystemDetails.Rows.Add();
			RoleDetails.IsRole = True;
			RoleDetails.Name     = Role.Name;
			RoleDetails.Synonym = ?(ValueIsFilled(Role.Synonym), Role.Synonym, Role.Name);
		EndDo;
		
		Filter = New Structure("IsRole", True);
		If SubsystemDetails.Rows.FindRows(Filter, True).Count() = 0 Then
			TreeRowCollection.Delete(SubsystemDetails);
		EndIf;
	EndDo;
	
EndProcedure

Procedure CheckAssignment(Assignment, ErrorTitle)
	
	If Assignment <> "ForAdministrators"
	   AND Assignment <> "ForUsers"
	   AND Assignment <> "ForExternalUsers"
	   AND Assignment <> "BothForUsersAndExternalUsers" Then
		
		Raise ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Параметр Assignment ""%1"" указан некорректно.
			           |
			           |Допустимы только следующие значения:
			           |- ""ForAdministrators"",
			           |- ""ForUsers"",
			           |- ""ForExternalUsers"",
			           |- ""BothForUsersAndExternalUsers"".'; 
			           |en = 'Invalid value of Assignment parameter: ""%1.""
			           |
			           |Valid values are:
			           |- ForAdministrators
			           |- ForUsers
			           |- ForExternalUsers
			           |- BothForUsersAndExternalUsers'; 
			           |pl = 'Parametr Naznaczenie ""%1"" jest podany błędnie. 
			           |
			           |Dopuszczalne są jedynie następujące znaczenia:
			           |- ""ForAdministrator"",
			           |- ""ForUsers"",
			           |-""ForExternalUsers,
			           |- ""BothForUsersAndExternalUsers.';
			           |es_ES = 'El parámetro Asignación ""%1"" está indicado incorrectamente. 
			           |
			           |Se admiten solo los siguientes valores:
			           |- ForAdministrators,
			           |- ForUsers,
			           |- ForExternalUsers,
			           |- BothForUsersAndExternalUsers';
			           |es_CO = 'El parámetro Asignación ""%1"" está indicado incorrectamente. 
			           |
			           |Se admiten solo los siguientes valores:
			           |- ForAdministrators,
			           |- ForUsers,
			           |- ForExternalUsers,
			           |- BothForUsersAndExternalUsers';
			           |tr = 'Amaç parametresi ""%1"" yanlış belirtildi. 
			           |
			           |Sadece aşağıdaki değerlere izin verildi: 
			           |- ""Yöneticilerİçin"", 
			           |- ""Kullanıcılarİçin"", 
			           |- ""HariciKullanıcılarİçin"", -
			           | - ""KullanıcılarVeHariciKullanıcılarİçinBirlikte"".';
			           |it = 'Il parametro Designazione ""%1"" è indicato incorrettamente.
			           |
			           |Sono ammessi solo i seguenti valori:
			           |- ""PerGliAmministratori"",
			           |- ""PerGliUtenti"",
			           |- ""PerGliUtentiEsterni"",
			           |- ""ContemporaneamentePerGliUtentiEPerGliUtentiEsterni""';
			           |de = 'Der Parameter Assignment ist nicht korrekt angegeben: ""%1"".
			           |
			           |Es sind nur folgende Werte erlaubt:
			           |- ""ForAdministrators"",
			           |- ""ForUsers"",
			           |- ""ForExternalUsers"",
			           |- ""BothForUsersAndExternalUsersBenutzer"".'"),
			Assignment);
	EndIf;
	
EndProcedure

#EndRegion
