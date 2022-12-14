#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns the object attributes that are not recommended to be edited using batch attribute 
// modification┬ádata processor.
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToSkipInBatchProcessing() Export
	
	AttributesToSkip = New Array;
	AttributesToSkip.Add("AuthorizationObject");
	AttributesToSkip.Add("SetRolesDirectly");
	AttributesToSkip.Add("IBUserID");
	AttributesToSkip.Add("ServiceUserID");
	AttributesToSkip.Add("IBUserProperies");
	AttributesToSkip.Add("DeletePassword");
	
	Return AttributesToSkip;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.TextForExternalUsers =
	"AllowRead
	|WHERE
	|	ValueAllowed(Ref)
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	IsAuthorizedUser(Ref)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If NOT Parameters.Filter.Property("Invalid") Then
		Parameters.Filter.Insert("Invalid", False);
	EndIf;
	
EndProcedure

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormType = "ObjectForm" AND Parameters.Property("AuthorizationObject") Then
		
		StandardProcessing = False;
		SelectedForm = "ItemForm";
		
		FoundExternalUser = Undefined;
		CanAddExternalUser = False;
		
		AuthorizationObjectIsInUse = UsersInternalServerCall.AuthorizationObjectIsInUse(
			Parameters.AuthorizationObject,
			Undefined,
			FoundExternalUser,
			CanAddExternalUser);
		
		If AuthorizationObjectIsInUse Then
			Parameters.Insert("Key", FoundExternalUser);
			
		ElsIf CanAddExternalUser Then
			
			Parameters.Insert(
				"NewExternalUserAuthorizationObject", Parameters.AuthorizationObject);
		Else
			ErrorAsWarningDetails =
				NStr("ru = 'đáđ░đĚĐÇđÁĐłđÁđŻđŞđÁ đŻđ░ đ▓Đůđżđ┤ đ▓ đ┐ĐÇđżđ│ĐÇđ░đ╝đ╝Đâ đŻđÁ đ┐ĐÇđÁđ┤đżĐüĐéđ░đ▓đ╗ĐĆđ╗đżĐüĐî.'; en = 'The right to sign in is not granted.'; pl = 'Brak uprawnie┼ä do logowania si─Ö do aplikacji.';es_ES = 'No hay permiso para iniciar sesi├│n de la aplicaci├│n.';es_CO = 'No hay permiso para iniciar sesi├│n de la aplicaci├│n.';tr = 'Uygulamaya giri┼č izni verilmedi.';it = 'Il permesso di accesso non ├Ę stato concesso.';de = 'Keine Berechtigung zur Anmeldung bei der Anwendung.'");
				
			Raise ErrorAsWarningDetails;
		EndIf;
		
		Parameters.Delete("AuthorizationObject");
	EndIf;
	
EndProcedure

#EndRegion
