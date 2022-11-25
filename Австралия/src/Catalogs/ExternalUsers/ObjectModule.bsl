#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var IBUserProcessingParameters; // The parameters that are filled when processing an infobase user.
                                        // Used in OnWrite event handler.

Var IsNew; // Shows whether a new object was written.
                // Used in OnWrite event handler.

Var PreviousAuthorizationObject; // The previous value of an authorization object.
                               // Used in OnWrite event handler.

#EndRegion

// *Region Public.
//
// The object interface is implemented through AdditionalProperties:
//
// IBUserDetails - Structure, see the description in the object module of the Users catalog.
//
// *EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	IsNew = IsNew();
	
	If NOT ValueIsFilled(AuthorizationObject) Then
		Raise NStr("ru = 'У внешнего пользователя не задан объект авторизации.'; en = 'No authorization object is set for the external user.'; pl = 'Dla użytkownika zewnętrznego nie jest ustawiony obiekt autoryzacji.';es_ES = 'Objeto de autorización no está establecido para un usuario externo.';es_CO = 'Objeto de autorización no está establecido para un usuario externo.';tr = 'Harici kullanıcı için yetkilendirme nesnesi belirlenmedi.';it = 'Nessun oggetto di autorizzazione è impostato per l''utente esterno.';de = 'Das Berechtigungsobjekt ist für einen externen Benutzer nicht festgelegt.'");
	Else
		ErrorText = "";
		If UsersInternal.AuthorizationObjectIsInUse(
		         AuthorizationObject, Ref, , , ErrorText) Then
			
			Raise ErrorText;
		EndIf;
	EndIf;
	
	// Checking whether the authorization object was not changed.
	If IsNew Then
		PreviousAuthorizationObject = NULL;
	Else
		PreviousAuthorizationObject = Common.ObjectAttributeValue(
			Ref, "AuthorizationObject");
		
		If ValueIsFilled(PreviousAuthorizationObject)
		   AND PreviousAuthorizationObject <> AuthorizationObject Then
			
			Raise NStr("ru = 'Невозможно изменить ранее указанный объект авторизации.'; en = 'Cannot change a previously specified authorization object.'; pl = 'Nie można zmienić wcześniej określonego obiektu autoryzacji.';es_ES = 'No se puede cambiar el objeto de autorización previamente especificado.';es_CO = 'No se puede cambiar el objeto de autorización previamente especificado.';tr = 'Daha önce belirlenen yetkilendirme nesnesi değiştirilemez.';it = 'Non è possibile modificare un oggetto di autorizzazione specificato precedentemente.';de = 'Das zuvor angegebene Berechtigungsobjekt kann nicht geändert werden.'");
		EndIf;
	EndIf;
	
	UsersInternal.StartIBUserProcessing(ThisObject, IBUserProcessingParameters);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Updating the content of the group that contains the new external user (provided that it is in a group).
	If AdditionalProperties.Property("NewExternalUserGroup")
	   AND ValueIsFilled(AdditionalProperties.NewExternalUserGroup) Then
		
		Lock = New DataLock;
		LockItem = Lock.Add("Catalog.ExternalUsersGroups");
		Lock.Lock();
		
		GroupObject = AdditionalProperties.NewExternalUserGroup.GetObject();
		GroupObject.Content.Add().ExternalUser = Ref;
		GroupObject.Write();
	EndIf;
	
	// Updating the content of the "All external users" automatic group.
	ItemsToChange = New Map;
	ModifiedGroups   = New Map;
	
	UsersInternal.UpdateExternalUserGroupCompositions(
		Catalogs.ExternalUsersGroups.AllExternalUsers,
		Ref,
		ItemsToChange,
		ModifiedGroups);
	
	UsersInternal.UpdateUserGroupCompositionUsage(
		Ref, ItemsToChange, ModifiedGroups);
	
	UsersInternal.EndIBUserProcessing(
		ThisObject, IBUserProcessingParameters);
	
	UsersInternal.AfterUpdateExternalUserGroupCompositions(
		ItemsToChange,
		ModifiedGroups);
	
	If PreviousAuthorizationObject <> AuthorizationObject Then
		SSLSubsystemsIntegration.AfterChangeExternalUserAuthorizationObject(
			Ref, PreviousAuthorizationObject, AuthorizationObject);
	EndIf;
	
	UsersInternal.EnableUserActivityMonitoringJobIfRequired(Ref);
	
	SSLSubsystemsIntegration.AfterAddChangeUserOrGroup(Ref, IsNew);
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CommonActionsBeforeDeleteInNormalModeAndDuringDataExchange();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	AdditionalProperties.Insert("CopyingValue", CopiedObject.Ref);
	
	IBUserID = Undefined;
	ServiceUserID = Undefined;
	Prepared = False;
	
	Comment = "";
	
EndProcedure

#EndRegion

#Region Private

// For internal use only.
Procedure CommonActionsBeforeDeleteInNormalModeAndDuringDataExchange() Export
	
	// The infobase user must be deleted. Otherwise, they will be added to the IBUsers form error list, 
	// and any attempt to sign in as this user will result in error.
	
	IBUserDetails = New Structure;
	IBUserDetails.Insert("Action", "Delete");
	AdditionalProperties.Insert("IBUserDetails", IBUserDetails);
	
	UsersInternal.StartIBUserProcessing(ThisObject, IBUserProcessingParameters, True);
	UsersInternal.EndIBUserProcessing(ThisObject, IBUserProcessingParameters);
	
EndProcedure

#EndRegion

#EndIf