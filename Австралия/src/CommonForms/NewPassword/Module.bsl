
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.ForExternalUser Then
		AuthorizationSettings = UsersInternalCached.Settings().ExternalUsers;
	Else
		AuthorizationSettings = UsersInternalCached.Settings().Users;
	EndIf;
	
	MinPasswordLength = GetUserPasswordMinLength();
	
	If MinPasswordLength < AuthorizationSettings.MinPasswordLength Then
		MinPasswordLength = AuthorizationSettings.MinPasswordLength;
	EndIf;
	
	If MinPasswordLength <= 8 Then
		MinPasswordLength = 8;
	EndIf;
	
	PasswordParameters = UsersInternal.PasswordParameters(MinPasswordLength, True);
	
	NewPassword = UsersInternal.CreatePassword(PasswordParameters);
	
EndProcedure

#EndRegion
