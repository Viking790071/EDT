#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var ValueChanged;

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ValueChanged = Value <> Constants.UseExternalUsers.Get();
	
	If ValueChanged
	   AND Value
	   AND Not UsersInternal.ExternalUsersEmbedded() Then
		Raise NStr("ru = 'Использование внешних пользователей не предусмотрено в программе.'; en = 'The application does not support external users.'; pl = 'Korzystanie z zewnętrznych użytkowników nie jest przewidziane w programie.';es_ES = 'El uso de los usuarios externos no está previsto en el programa.';es_CO = 'El uso de los usuarios externos no está previsto en el programa.';tr = 'Uygulamada harici kullanıcıların kullanımı öngörülmemiştir.';it = 'L''applicazione non supporta utenti esterni';de = 'Die Verwendung von externen Benutzern ist im Programm nicht vorgesehen.'");
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueChanged Then
		UsersInternal.UpdateExternalUsersRoles();
		If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
			ModuleAccessManagement = Common.CommonModule("AccessManagement");
			ModuleAccessManagement.UpdateUserRoles(Type("CatalogRef.ExternalUsers"));
			
			ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
			If ModuleAccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
				PlanningParameters = ModuleAccessManagementInternal.AccessUpdatePlanningParameters();
				PlanningParameters.ForUsers = False;
				PlanningParameters.ForExternalUsers = True;
				ModuleAccessManagementInternal.ScheduleAccessUpdate(, PlanningParameters);
			EndIf;
		EndIf;
		If Value Then
			ClearShowInListAttributeForAllIBUsers();
		Else
			ClearCanSignInAttributeForAllExternalUsers();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Clears the FlagShowInList attribute for all infobase users.
Procedure ClearShowInListAttributeForAllIBUsers() Export
	
	IBUsers = InfoBaseUsers.GetUsers();
	For Each InfobaseUser In IBUsers Do
		If InfobaseUser.ShowInList Then
			InfobaseUser.ShowInList = False;
			InfobaseUser.Write();
		EndIf;
	EndDo;
	
EndProcedure

// Clears the FlagShowInList attribute for all infobase users.
Procedure ClearCanSignInAttributeForAllExternalUsers()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ExternalUsers.IBUserID AS ID
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers";
	IDs = Query.Execute().Unload();
	IDs.Indexes.Add("ID");
	
	IBUsers = InfoBaseUsers.GetUsers();
	For Each InfobaseUser In IBUsers Do
		
		If IDs.Find(InfobaseUser.UUID, "ID") <> Undefined
		   AND Users.CanSignIn(InfobaseUser) Then
			
			InfobaseUser.StandardAuthentication = False;
			InfobaseUser.OSAuthentication          = False;
			InfobaseUser.OpenIDAuthentication      = False;
			InfobaseUser.Write();
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
